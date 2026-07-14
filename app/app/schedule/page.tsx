"use client";

import { useCallback, useEffect, useState } from "react";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Chip from "@mui/material/Chip";
import CircularProgress from "@mui/material/CircularProgress";
import Dialog from "@mui/material/Dialog";
import DialogActions from "@mui/material/DialogActions";
import DialogContent from "@mui/material/DialogContent";
import DialogTitle from "@mui/material/DialogTitle";
import Divider from "@mui/material/Divider";
import Grid from "@mui/material/Grid";
import List from "@mui/material/List";
import ListItemButton from "@mui/material/ListItemButton";
import ListItemText from "@mui/material/ListItemText";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import Link from "next/link";

type Lecture = {
  id: number;
  week: number;
  title: string;
  startsAt: string;
  state: "upcoming" | "live" | "done";
  slides: number;
  attendance: { status: string; joinedAt: string | null; lateMinutes: number } | null;
};

const STATE_COLOR = {
  live: "success",
  upcoming: "default",
  done: "default",
} as const;

const ATTENDANCE_COLOR: Record<string, "success" | "warning" | "error" | "default"> = {
  on_time: "success",
  late: "warning",
  absent: "error",
  upcoming: "default",
};

export default function SchedulePage() {
  const [lectures, setLectures] = useState<Lecture[] | null>(null);
  const [selected, setSelected] = useState<Lecture | null>(null);

  const load = useCallback(async () => {
    const res = await fetch("/api/lectures", { cache: "no-store" });
    const data = await res.json();
    setLectures(data.lectures);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (!lectures) return <CircularProgress />;

  return (
    <Stack spacing={3}>
      <Typography variant="h4">Schedule</Typography>
      <Typography variant="body1" color="text.secondary">
        Four lectures, one a week. Click a lecture for its details. Times follow the
        virtual clock, so the Admin page can jump you to any week.
      </Typography>

      <Card variant="outlined">
        <List>
          {lectures.map((lecture) => (
            <ListItemButton key={lecture.id} onClick={() => setSelected(lecture)}>
              <ListItemText
                primary={`Week ${lecture.week} — ${lecture.title}`}
                secondary={new Date(lecture.startsAt).toUTCString()}
              />
              <Grid container spacing={1}>
                {lecture.attendance ? (
                  <Grid>
                    <Chip
                      size="small"
                      color={ATTENDANCE_COLOR[lecture.attendance.status] ?? "default"}
                      label={
                        lecture.attendance.status === "late"
                          ? `late ${lecture.attendance.lateMinutes} min`
                          : lecture.attendance.status
                      }
                    />
                  </Grid>
                ) : null}
                <Grid>
                  <Chip
                    size="small"
                    color={STATE_COLOR[lecture.state]}
                    variant={lecture.state === "live" ? "filled" : "outlined"}
                    label={lecture.state}
                  />
                </Grid>
              </Grid>
            </ListItemButton>
          ))}
        </List>
      </Card>

      <Dialog open={Boolean(selected)} onClose={() => setSelected(null)} fullWidth maxWidth="sm">
        <DialogTitle>
          {selected ? `Week ${selected.week} — ${selected.title}` : ""}
        </DialogTitle>
        <DialogContent dividers>
          {selected ? (
            <Stack spacing={2}>
              <Stack spacing={1}>
                <Typography variant="overline" color="text.secondary">
                  Starts at
                </Typography>
                <Typography variant="body1">
                  {new Date(selected.startsAt).toUTCString()}
                </Typography>
              </Stack>

              <Divider />

              <Grid container spacing={1}>
                <Grid>
                  <Chip
                    color={STATE_COLOR[selected.state]}
                    variant={selected.state === "live" ? "filled" : "outlined"}
                    label={selected.state}
                  />
                </Grid>
                <Grid>
                  <Chip variant="outlined" label={`${selected.slides} slides`} />
                </Grid>
              </Grid>

              <Divider />

              <Stack spacing={1}>
                <Typography variant="overline" color="text.secondary">
                  Your attendance
                </Typography>
                {selected.attendance ? (
                  <Typography variant="body1">
                    {selected.attendance.status === "late"
                      ? `Joined ${selected.attendance.lateMinutes} minutes late, at ${new Date(
                          selected.attendance.joinedAt ?? ""
                        ).toUTCString()}`
                      : selected.attendance.status === "on_time"
                        ? `Joined on time, at ${new Date(
                            selected.attendance.joinedAt ?? ""
                          ).toUTCString()}`
                        : selected.attendance.status === "absent"
                          ? "Absent — you never joined this lecture."
                          : "Not yet — this lecture has not started."}
                  </Typography>
                ) : (
                  <Typography variant="body1" color="text.secondary">
                    Nothing recorded yet.
                  </Typography>
                )}
              </Stack>
            </Stack>
          ) : null}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSelected(null)}>Close</Button>
          {selected ? (
            <Button
              variant="contained"
              component={Link}
              href={`/lecture/${selected.id}`}
              disabled={selected.state === "upcoming"}
            >
              {selected.state === "live" ? "Join lecture" : "Open lecture"}
            </Button>
          ) : null}
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
