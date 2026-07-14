"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Alert from "@mui/material/Alert";
import AlertTitle from "@mui/material/AlertTitle";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Chip from "@mui/material/Chip";
import CircularProgress from "@mui/material/CircularProgress";
import LinearProgress from "@mui/material/LinearProgress";
import Stack from "@mui/material/Stack";
import Table from "@mui/material/Table";
import TableBody from "@mui/material/TableBody";
import TableCell from "@mui/material/TableCell";
import TableHead from "@mui/material/TableHead";
import TableRow from "@mui/material/TableRow";
import Typography from "@mui/material/Typography";
import Link from "next/link";

type Book = {
  id: number;
  filename: string;
  title: string | null;
  pages: number;
  status: string;
  error: string | null;
  uploaded_at: string;
};

const STATUS_COLOR: Record<string, "success" | "error" | "warning" | "default"> = {
  ready: "success",
  failed: "error",
  ingesting: "warning",
  pending: "default",
};

export default function BooksPage() {
  const [books, setBooks] = useState<Book[] | null>(null);
  const [ragConfigured, setRagConfigured] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    const res = await fetch("/api/upload", { cache: "no-store" });
    const data = await res.json();
    setBooks(data.books ?? []);
    setRagConfigured(data.ragConfigured);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function upload(file: File) {
    setBusy(true);
    setError(null);
    try {
      const body = new FormData();
      body.append("file", file);
      const res = await fetch("/api/upload", { method: "POST", body });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail ? `${data.error} (${data.detail})` : data.error);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed.");
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  if (!books) return <CircularProgress />;

  // MVP-1 is one book, one month. Once the book is in, this page is a library view:
  // there is nothing left to upload, so we do not offer it.
  const hasBook = books.length > 0;

  return (
    <Stack spacing={3}>
      <Typography variant="h4">{hasBook ? "Your books" : "Upload your book"}</Typography>

      {error ? (
        <Alert severity="error">
          <AlertTitle>Upload failed</AlertTitle>
          {error}
        </Alert>
      ) : null}

      {!ragConfigured ? (
        <Alert severity="info">
          RAG_MCP_URL is not set, so a book would be stored but never indexed.
        </Alert>
      ) : null}

      {hasBook ? (
        <Stack spacing={3}>
          <Card variant="outlined">
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Book</TableCell>
                  <TableCell>File</TableCell>
                  <TableCell align="right">Pages</TableCell>
                  <TableCell>Uploaded</TableCell>
                  <TableCell>Status</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {books.map((book) => (
                  <TableRow key={book.id}>
                    <TableCell>{book.title ?? book.filename}</TableCell>
                    <TableCell>{book.filename}</TableCell>
                    <TableCell align="right">{book.pages || "—"}</TableCell>
                    <TableCell>{new Date(book.uploaded_at).toUTCString()}</TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        color={STATUS_COLOR[book.status] ?? "default"}
                        label={book.status === "ready" ? "indexed" : book.status}
                      />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Card>

          {books.some((book) => book.error) ? (
            <Alert severity="error">{books.find((book) => book.error)?.error}</Alert>
          ) : null}

          <Alert
            severity="success"
            action={
              <Button component={Link} href="/schedule" size="small">
                Go to schedule
              </Button>
            }
          >
            Your semester is built from this book. A course takes one book — to study a
            different one, start a new course.
          </Alert>
        </Stack>
      ) : (
        <Stack spacing={3}>
          <Typography variant="body1" color="text.secondary">
            One textbook PDF. It is handed to the RAG service, which indexes it so lectures
            and answers can cite the page they came from.
          </Typography>

          <Card variant="outlined">
            <CardContent>
              <Stack spacing={2}>
                <Button variant="contained" component="label" disabled={busy}>
                  Choose PDF
                  <input
                    ref={inputRef}
                    type="file"
                    accept="application/pdf,.pdf"
                    hidden
                    onChange={(event) => {
                      const file = event.target.files?.[0];
                      if (file) upload(file);
                    }}
                  />
                </Button>

                {busy ? (
                  <Stack spacing={1}>
                    <Typography variant="body2" color="text.secondary">
                      Sending the book to the RAG service for indexing…
                    </Typography>
                    <LinearProgress />
                  </Stack>
                ) : null}
              </Stack>
            </CardContent>
          </Card>
        </Stack>
      )}
    </Stack>
  );
}
