import { NextRequest } from "next/server";
import { promises as fs } from "fs";
import path from "path";
import { query, queryOne } from "@/lib/db";
import { now } from "@/lib/clock";
import { runPython, parseJsonLine, REPO_ROOT } from "@/lib/python";
import { env } from "@/lib/env";

export const dynamic = "force-dynamic";
export const maxDuration = 600;

const MAX_BYTES = 60 * 1024 * 1024;
const PDF_MAGIC = "%PDF-";

/**
 * Indexing is the RAG service's job — it is already built, owned by the team,
 * and lives in its own repo. This route validates the file, saves it, and hands
 * the path to RAG's ingest_file tool over MCP. It never chunks or embeds anything.
 */
const RAG_MCP_URL = env.RAG_MCP_URL;

type Book = {
  id: number;
  filename: string;
  title: string | null;
  pages: number;
  status: string;
  error: string | null;
};

const BOOK_COLUMNS = "id, filename, title, pages, status, error";

export async function GET() {
  const books = await query<Book & { uploaded_at: string }>(
    `SELECT ${BOOK_COLUMNS}, uploaded_at FROM books ORDER BY id DESC`
  );
  return Response.json({
    books,
    book: books[0] ?? null,
    ragConfigured: Boolean(RAG_MCP_URL),
  });
}

export async function POST(request: NextRequest) {
  // A course is built from ONE book. Once it is in, uploading is closed — the page
  // becomes a library view, and this guard means the API agrees with it.
  const existing = await queryOne<{ count: string }>("SELECT COUNT(*)::text AS count FROM books");
  if (Number(existing?.count ?? 0) > 0) {
    return Response.json(
      { error: "This course already has its book. Start a new course to study a different one." },
      { status: 409 }
    );
  }

  const form = await request.formData().catch(() => null);
  const file = form?.get("file");

  if (!file || typeof file === "string") {
    return Response.json({ error: "No file uploaded." }, { status: 400 });
  }
  if (!file.name.toLowerCase().endsWith(".pdf")) {
    return Response.json({ error: "Only PDF files are accepted." }, { status: 400 });
  }
  if (file.size > MAX_BYTES) {
    return Response.json(
      { error: `That file is ${(file.size / 1e6).toFixed(1)} MB. The limit is 60 MB.` },
      { status: 400 }
    );
  }

  const bytes = Buffer.from(await file.arrayBuffer());
  if (bytes.subarray(0, 5).toString("latin1") !== PDF_MAGIC) {
    return Response.json(
      { error: "That file is not a real PDF — its contents do not start with %PDF-." },
      { status: 400 }
    );
  }

  const uploadsDir = path.join(REPO_ROOT, "uploads");
  await fs.mkdir(uploadsDir, { recursive: true });
  const safeName = file.name.replace(/[^\w.\-]+/g, "_");
  const destination = path.join(uploadsDir, safeName);
  await fs.writeFile(destination, bytes);

  // MVP-1 holds exactly one book: a new upload replaces the previous one.
  await query("DELETE FROM books");
  const uploadedAt = await now();
  const created = await queryOne<{ id: number }>(
    "INSERT INTO books (filename, status, uploaded_at) VALUES ($1, $2, $3) RETURNING id",
    [safeName, RAG_MCP_URL ? "ingesting" : "pending", uploadedAt]
  );
  const bookId = created!.id;

  if (!RAG_MCP_URL) {
    return Response.json({
      book: await queryOne<Book>(`SELECT ${BOOK_COLUMNS} FROM books WHERE id = $1`, [bookId]),
      ragConfigured: false,
      note: "Saved. RAG_MCP_URL is not set, so the book was not sent for indexing.",
    });
  }

  const result = await runPython("services/rag_ingest.py", [destination]);
  const payload = parseJsonLine<{ ok: boolean; message?: string; error?: string }>(result.stdout);

  if (!payload?.ok) {
    const detail = payload?.error ?? result.stderr.trim().split("\n").slice(-2).join(" ");
    await query("UPDATE books SET status = 'failed', error = $1 WHERE id = $2", [detail, bookId]);
    return Response.json(
      { error: "The RAG service could not index this book.", detail },
      { status: 502 }
    );
  }

  // Their tool answers with prose, e.g. "Successfully ingested x.pdf. Created 5 chunks."
  const chunks = Number(payload.message?.match(/Created (\d+) chunks/)?.[1] ?? 0);
  await query("UPDATE books SET status = 'ready', title = $1 WHERE id = $2", [safeName, bookId]);

  return Response.json({
    book: await queryOne<Book>(`SELECT ${BOOK_COLUMNS} FROM books WHERE id = $1`, [bookId]),
    ragConfigured: true,
    chunks,
    message: payload.message,
  });
}
