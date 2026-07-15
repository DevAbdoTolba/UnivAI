"use client";

import { useCallback, useEffect, useState } from "react";
import Alert from "@mui/material/Alert";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import Chip from "@mui/material/Chip";
import CircularProgress from "@mui/material/CircularProgress";
import Grid from "@mui/material/Grid";
import List from "@mui/material/List";
import ListItem from "@mui/material/ListItem";
import ListItemText from "@mui/material/ListItemText";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import { formatCountdown, formatDateTime, formatRelative, useVirtualClock } from "@/lib/time";

type Exam = {
  kind: "quiz" | "mid";
  week: number | null;
  title: string;
  opensAt: string;
  closesAt: string;
  state: "locked" | "open" | "missed" | "submitted";
  score: string | null;
  maxScore: string | null;
  flagged: boolean;
};

const STATE_COLOR: Record<Exam["state"], "default" | "success" | "error" | "warning"> = {
  locked: "default",
  open: "success",
  missed: "error",
  submitted: "default",
};

export default function ExamsPage() {
  const [exams, setExams] = useState<Exam[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [starting, setStarting] = useState(false);
  const now = useVirtualClock();

  const load = useCallback(async () => {
    const res = await fetch("/api/exams", { cache: "no-store" });
    const data = await res.json();
    setExams(data.exams);
  }, []);

  useEffect(() => {
    load();
    const refresh = setInterval(load, 15_000);
    return () => clearInterval(refresh);
  }, [load]);

  async function start(exam: Exam) {
    setStarting(true);
    setError(null);
    try {
      const res = await fetch("/api/exams", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ kind: exam.kind, week: exam.week }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Could not start the exam.");
      window.open(data.url, "_blank", "noopener");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not start the exam.");
    } finally {
      setStarting(false);
    }
  }

  if (!exams) return <CircularProgress />;

  /** One plain sentence about the window, measured on the virtual clock. */
  function windowLine(exam: Exam): string {
    if (!now) return "";
    const opens = new Date(exam.opensAt).getTime() - now.getTime();
    const closes = new Date(exam.closesAt).getTime() - now.getTime();

    if (exam.state === "submitted") return `Submitted — score ${exam.score} / ${exam.maxScore}.`;
    if (exam.state === "missed") return `Window closed ${formatRelative(exam.closesAt, now)}.`;
    if (exam.state === "open") return `Open now — closes in ${formatCountdown(closes)}.`;
    return `Opens after the lecture, ${formatRelative(exam.opensAt, now)} (${formatDateTime(exam.opensAt)}). You get ${
      exam.kind === "mid" ? "3 days" : "24 hours"
    }.`;
  }

  const openNow = exams.filter((exam) => exam.state === "open");

  return (
    <Stack spacing={3}>
      <Typography variant="h4">Exams</Typography>
      <Typography variant="body1" color="text.secondary">
        A quiz opens when its lecture ends and stays open for 24 hours. The midterm opens
        after week 4 and stays open for 3 days. Exams run in the exam system and your
        results come back to the dashboard.
      </Typography>

      {openNow.length ? (
        <Alert severity="warning">
          {openNow.length === 1
            ? `${openNow[0].title} is open — ${windowLine(openNow[0]).toLowerCase()}`
            : `${openNow.length} exams are open right now — do not miss the deadlines.`}
        </Alert>
      ) : null}

      {error ? <Alert severity="error">{error}</Alert> : null}

      <Card variant="outlined">
        <List>
          {exams.map((exam) => (
            <ListItem
              key={`${exam.kind}-${exam.week ?? "mid"}`}
              secondaryAction={
                <Grid container spacing={1}>
                  {exam.flagged ? (
                    <Grid>
                      <Chip size="small" color="error" label="integrity flag" />
                    </Grid>
                  ) : null}
                  {exam.state === "submitted" ? (
                    <Grid>
                      <Chip
                        size="small"
                        variant="outlined"
                        label={`${exam.score} / ${exam.maxScore}`}
                      />
                    </Grid>
                  ) : null}
                  <Grid>
                    <Chip
                      size="small"
                      color={STATE_COLOR[exam.state]}
                      variant={exam.state === "open" ? "filled" : "outlined"}
                      label={exam.state}
                    />
                  </Grid>
                  <Grid>
                    <Button
                      variant="contained"
                      size="small"
                      disabled={exam.state !== "open" || starting}
                      onClick={() => start(exam)}
                    >
                      {exam.kind === "mid" ? "Take midterm" : "Take quiz"}
                    </Button>
                  </Grid>
                </Grid>
              }
            >
              <ListItemText primary={exam.title} secondary={windowLine(exam)} />
            </ListItem>
          ))}
        </List>
      </Card>
    </Stack>
  );
}
