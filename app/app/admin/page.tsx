"use client";

import { useCallback, useEffect, useState } from "react";
import Alert from "@mui/material/Alert";
import Button from "@mui/material/Button";
import ButtonGroup from "@mui/material/ButtonGroup";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Chip from "@mui/material/Chip";
import CircularProgress from "@mui/material/CircularProgress";
import Divider from "@mui/material/Divider";
import Grid from "@mui/material/Grid";
import Stack from "@mui/material/Stack";
import Table from "@mui/material/Table";
import TableBody from "@mui/material/TableBody";
import TableCell from "@mui/material/TableCell";
import TableHead from "@mui/material/TableHead";
import TableRow from "@mui/material/TableRow";
import TextField from "@mui/material/TextField";
import Typography from "@mui/material/Typography";
import { formatCountdown, formatDateTime, formatLateness, formatRelative } from "@/lib/time";

type AdminState = {
  clock: { now: string; offsetMs: number };
  books: Array<Record<string, unknown>>;
  lectures: Array<{ id: number; week: number; title: string; starts_at: string; status: string }>;
  attendance: Array<{
    lectureId: number;
    week: number;
    title: string;
    startsAt: string;
    status: string;
    joinedAt: string | null;
    lateMinutes: number;
  }>;
  attendanceSummary: {
    onTimeCount: number;
    lateCount: number;
    absentCount: number;
    upcomingCount: number;
    totalLateMinutes: number;
    averageLateMinutes: number;
  };
  grades: Array<{
    id: number;
    kind: string;
    week: number | null;
    score: string;
    max_score: string;
    feedback: string | null;
    flagged?: boolean;
    report?: { suspicion_score?: number; events?: unknown[] } | null;
  }>;
  qaLog: Array<{
    id: number;
    question: string;
    answer: string;
    model_used: string | null;
    asked_at: string;
  }>;
};

export default function AdminPage() {
  const [state, setState] = useState<AdminState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [isoInput, setIsoInput] = useState("");

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/admin/state", { cache: "no-store" });
      if (!res.ok) throw new Error(await res.text());
      setState(await res.json());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed to load state");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function control(body: Record<string, unknown>) {
    setBusy(true);
    try {
      const res = await fetch("/api/clock", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "clock control failed");
      setError(null);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "clock control failed");
    } finally {
      setBusy(false);
    }
  }

  if (!state && !error) return <CircularProgress />;

  const summary = state?.attendanceSummary;

  return (
    <Stack spacing={3}>
      <Typography variant="h4">Admin — SUDO</Typography>
      <Alert severity="warning">
        No authentication. Local demo only — never deploy this page publicly.
      </Alert>

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Virtual clock</Typography>

            <Grid container spacing={1}>
              <Grid>
                <Chip color="primary" label={`now: ${formatDateTime(state?.clock.now)}`} />
              </Grid>
              <Grid>
                <Chip
                  variant="outlined"
                  label={
                    state?.clock.offsetMs
                      ? `${formatCountdown(Math.abs(state.clock.offsetMs))} ${
                          state.clock.offsetMs > 0 ? "ahead of" : "behind"
                        } real time`
                      : "real time"
                  }
                />
              </Grid>
            </Grid>

            <ButtonGroup variant="contained" disabled={busy}>
              <Button onClick={() => control({ action: "advance", minutes: 5 })}>+5 min</Button>
              <Button onClick={() => control({ action: "advance", hours: 1 })}>+1 hour</Button>
              <Button onClick={() => control({ action: "advance", days: 1 })}>+1 day</Button>
              <Button onClick={() => control({ action: "advance", weeks: 1 })}>+1 week</Button>
            </ButtonGroup>

            <Grid container spacing={2}>
              <Grid>
                <Button
                  variant="outlined"
                  disabled={busy}
                  onClick={() => control({ action: "jumpToNextLecture" })}
                >
                  Jump to next lecture start
                </Button>
              </Grid>
              <Grid>
                <Button
                  variant="outlined"
                  color="secondary"
                  disabled={busy}
                  onClick={() => control({ action: "reset" })}
                >
                  Reset to real time
                </Button>
              </Grid>
            </Grid>

            <Divider />

            <Grid container spacing={2}>
              <Grid>
                <TextField
                  label="Set exact time (ISO)"
                  size="small"
                  placeholder="2026-08-01T10:00:00Z"
                  value={isoInput}
                  onChange={(event) => setIsoInput(event.target.value)}
                />
              </Grid>
              <Grid>
                <Button
                  variant="contained"
                  disabled={busy || !isoInput}
                  onClick={() => control({ action: "set", iso: isoInput })}
                >
                  Set
                </Button>
              </Grid>
            </Grid>
          </Stack>
        </CardContent>
      </Card>

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Book</Typography>
            {state?.books.length ? (
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>File</TableCell>
                    <TableCell>Title</TableCell>
                    <TableCell align="right">Pages</TableCell>
                    <TableCell>Status</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {state.books.map((book) => (
                    <TableRow key={String(book.id)}>
                      <TableCell>{String(book.filename)}</TableCell>
                      <TableCell>{String(book.title ?? "—")}</TableCell>
                      <TableCell align="right">{String(book.pages)}</TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          label={String(book.status)}
                          color={book.status === "ready" ? "success" : "default"}
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : (
              <Typography color="text.secondary">No book uploaded yet.</Typography>
            )}
          </Stack>
        </CardContent>
      </Card>

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Attendance</Typography>
            <Grid container spacing={1}>
              <Grid>
                <Chip color="success" label={`on time: ${summary?.onTimeCount ?? 0}`} />
              </Grid>
              <Grid>
                <Chip color="warning" label={`late: ${summary?.lateCount ?? 0}`} />
              </Grid>
              <Grid>
                <Chip color="error" label={`absent: ${summary?.absentCount ?? 0}`} />
              </Grid>
              <Grid>
                <Chip variant="outlined" label={`upcoming: ${summary?.upcomingCount ?? 0}`} />
              </Grid>
              <Grid>
                <Chip
                  variant="outlined"
                  label={`total late: ${summary?.totalLateMinutes ?? 0} min`}
                />
              </Grid>
              <Grid>
                <Chip
                  variant="outlined"
                  label={`avg late: ${summary?.averageLateMinutes ?? 0} min`}
                />
              </Grid>
            </Grid>
            {state?.attendance.length ? (
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Week</TableCell>
                    <TableCell>Lecture</TableCell>
                    <TableCell>Starts at</TableCell>
                    <TableCell>Joined at</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell align="right">Lateness</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {state.attendance.map((record) => (
                    <TableRow key={record.lectureId}>
                      <TableCell>{record.week}</TableCell>
                      <TableCell>{record.title}</TableCell>
                      <TableCell>{formatDateTime(record.startsAt)}</TableCell>
                      <TableCell>{formatDateTime(record.joinedAt)}</TableCell>
                      <TableCell>{record.status}</TableCell>
                      <TableCell align="right">{record.lateMinutes ? formatLateness(record.lateMinutes) : "—"}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : (
              <Typography color="text.secondary">No lectures scheduled yet.</Typography>
            )}
          </Stack>
        </CardContent>
      </Card>

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Grades</Typography>
            {state?.grades.length ? (
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Kind</TableCell>
                    <TableCell>Week</TableCell>
                    <TableCell align="right">Score</TableCell>
                    <TableCell>Feedback</TableCell>
                    <TableCell>Integrity</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {state.grades.map((grade) => (
                    <TableRow key={grade.id}>
                      <TableCell>{grade.kind}</TableCell>
                      <TableCell>{grade.week ?? "—"}</TableCell>
                      <TableCell align="right">{`${grade.score} / ${grade.max_score}`}</TableCell>
                      <TableCell>{grade.feedback ?? "—"}</TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          color={grade.flagged ? "error" : "success"}
                          label={
                            grade.flagged
                              ? `FLAGGED — suspicion ${grade.report?.suspicion_score ?? "?"}, ${grade.report?.events?.length ?? 0} events`
                              : `clean — ${grade.report?.events?.length ?? 0} events`
                          }
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : (
              <Typography color="text.secondary">No grades recorded yet.</Typography>
            )}
          </Stack>
        </CardContent>
      </Card>

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">Q&amp;A log (live-lecture questions)</Typography>
            {state?.qaLog.length ? (
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Asked</TableCell>
                    <TableCell>Question</TableCell>
                    <TableCell>Answer</TableCell>
                    <TableCell>Model</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {state.qaLog.map((entry) => (
                    <TableRow key={entry.id}>
                      <TableCell>{formatDateTime(entry.asked_at)}</TableCell>
                      <TableCell>{entry.question}</TableCell>
                      <TableCell>{entry.answer}</TableCell>
                      <TableCell>{entry.model_used ?? "—"}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : (
              <Typography color="text.secondary">No questions asked yet.</Typography>
            )}
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  );
}
