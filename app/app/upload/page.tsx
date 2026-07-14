"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Alert from "@mui/material/Alert";
import AlertTitle from "@mui/material/AlertTitle";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Chip from "@mui/material/Chip";
import Dialog from "@mui/material/Dialog";
import DialogActions from "@mui/material/DialogActions";
import DialogContent from "@mui/material/DialogContent";
import DialogContentText from "@mui/material/DialogContentText";
import DialogTitle from "@mui/material/DialogTitle";
import Grid from "@mui/material/Grid";
import LinearProgress from "@mui/material/LinearProgress";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";

type Book = {
  id: number;
  filename: string;
  title: string | null;
  pages: number;
  status: string;
  error: string | null;
};

export default function UploadPage() {
  const [book, setBook] = useState<Book | null>(null);
  const [ragConfigured, setRagConfigured] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmFile, setConfirmFile] = useState<File | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    const res = await fetch("/api/upload", { cache: "no-store" });
    const data = await res.json();
    setBook(data.book);
    setRagConfigured(data.ragConfigured);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const upload = useCallback(
    async (file: File) => {
      setBusy(true);
      setError(null);
      try {
        const body = new FormData();
        body.append("file", file);
        const res = await fetch("/api/upload", { method: "POST", body });
        const data = await res.json();
        if (!res.ok) throw new Error(data.detail ? `${data.error} (${data.detail})` : data.error);
        setBook(data.book);
        setRagConfigured(data.ragConfigured);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Upload failed.");
      } finally {
        setBusy(false);
        if (inputRef.current) inputRef.current.value = "";
      }
    },
    []
  );

  function onPick(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    // Replacing the book wipes its lectures and attendance: ask first.
    if (book) setConfirmFile(file);
    else upload(file);
  }

  return (
    <Stack spacing={3}>
      <Typography variant="h4">Upload your book</Typography>
      <Typography variant="body1" color="text.secondary">
        One textbook PDF. It is handed to the RAG service, which indexes it so lectures
        and answers can cite the page they came from.
      </Typography>

      {error ? (
        <Alert severity="error">
          <AlertTitle>Upload failed</AlertTitle>
          {error}
        </Alert>
      ) : null}

      {!ragConfigured ? (
        <Alert severity="info">
          RAG_INGEST_URL is not set, so uploads are stored but not indexed. Point it at
          the team&apos;s RAG service in .env.
        </Alert>
      ) : null}

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Button variant="contained" component="label" disabled={busy}>
              {book ? "Replace book" : "Choose PDF"}
              <input
                ref={inputRef}
                type="file"
                accept="application/pdf,.pdf"
                hidden
                onChange={onPick}
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

      {book ? (
        <Card variant="outlined">
          <CardContent>
            <Stack spacing={2}>
              <Typography variant="h6">{book.title ?? book.filename}</Typography>
              <Grid container spacing={1}>
                <Grid>
                  <Chip
                    color={book.status === "ready" ? "success" : book.status === "failed" ? "error" : "default"}
                    label={book.status === "ready" ? "book ready" : book.status}
                  />
                </Grid>
                <Grid>
                  <Chip variant="outlined" label={`${book.pages} pages`} />
                </Grid>
                <Grid>
                  <Chip variant="outlined" label={book.filename} />
                </Grid>
              </Grid>
              {book.error ? <Alert severity="error">{book.error}</Alert> : null}
              {book.status === "ready" ? (
                <Alert severity="success">
                  Your book is indexed. Next: open the schedule.
                </Alert>
              ) : null}
            </Stack>
          </CardContent>
        </Card>
      ) : (
        <Typography color="text.secondary">No book uploaded yet.</Typography>
      )}

      <Dialog open={Boolean(confirmFile)} onClose={() => setConfirmFile(null)}>
        <DialogTitle>Replace the current book?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            The current book, its lectures, and your attendance record will be deleted.
            This cannot be undone.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmFile(null)}>Cancel</Button>
          <Button
            color="error"
            variant="contained"
            onClick={() => {
              const file = confirmFile;
              setConfirmFile(null);
              if (file) upload(file);
            }}
          >
            Replace
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
