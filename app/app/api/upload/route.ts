import { NextRequest } from "next/server";
import { promises as fs } from "fs";
import path from "path";
import { query, queryOne } from "@/lib/db";
import { now } from "@/lib/clock";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

const MAX_BYTES = 60 * 1024 * 1024;
const PDF_MAGIC = "%PDF-";
const REPO_ROOT = path.resolve(process.cwd(), "..");

/**
 * Ingestion is the RAG service's job — it already exists and is owned by the
 * team, outside this repo. This route only validates the file, stores it, and
 * forwards it to RAG_INGEST_URL. It never chunks, embeds, or indexes anything.
 */
const RAG_INGEST_URL = process.env.RAG_INGEST_URL ?? "";

type Book = {
  id: number;
  filename: string;
  title: string | null;
  pages: number;
  status: string;
  error: string | null;
};

export async function GET() {
  const book = await queryOne<Book>(
    "SELECT id, filename, title, pages, status, error FROM books ORDER BY id DESC LIMIT 1"
  );
  return Response.json({ book, ragConfigured: Boolean(RAG_INGEST_URL) });
}

export async function POST(request: NextRequest) {
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
  await fs.writeFile(path.join(uploadsDir, safeName), bytes);

  // MVP-1 holds exactly one book: a new upload replaces the previous one.
  await query("DELETE FROM books");
  const uploadedAt = await now();
  const created = await queryOne<{ id: number }>(
    "INSERT INTO books (filename, status, uploaded_at) VALUES ($1, $2, $3) RETURNING id",
    [safeName, RAG_INGEST_URL ? "ingesting" : "pending", uploadedAt]
  );
  const bookId = created!.id;

  if (!RAG_INGEST_URL) {
    // The seam is here and nothing else: set RAG_INGEST_URL in .env when the
    // team's RAG service is reachable.
    return Response.json({
      book: await queryOne<Book>("SELECT id, filename, title, pages, status, error FROM books WHERE id = $1", [bookId]),
      ragConfigured: false,
      note: "Saved. RAG_INGEST_URL is not set, so the book was not sent for indexing.",
    });
  }

  try {
    const outbound = new FormData();
    outbound.append("file", new Blob([new Uint8Array(bytes)], { type: "application/pdf" }), safeName);

    const res = await fetch(RAG_INGEST_URL, { method: "POST", body: outbound });
    if (!res.ok) throw new Error(`RAG service returned ${res.status}: ${(await res.text()).slice(0, 200)}`);

    const data = (await res.json().catch(() => ({}))) as { title?: string; pages?: number };
    await query("UPDATE books SET status = 'ready', title = $1, pages = $2 WHERE id = $3", [
      data.title ?? safeName,
      data.pages ?? 0,
      bookId,
    ]);
  } catch (err) {
    const detail = err instanceof Error ? err.message : "unknown error";
    await query("UPDATE books SET status = 'failed', error = $1 WHERE id = $2", [detail, bookId]);
    return Response.json({ error: "The RAG service could not index this book.", detail }, { status: 502 });
  }

  return Response.json({
    book: await queryOne<Book>("SELECT id, filename, title, pages, status, error FROM books WHERE id = $1", [bookId]),
    ragConfigured: true,
  });
}
