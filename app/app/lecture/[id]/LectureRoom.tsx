"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  Room,
  RoomEvent,
  Track,
  createLocalAudioTrack,
  type LocalAudioTrack,
  type RemoteTrack,
  type RemoteTrackPublication,
} from "livekit-client";
import Alert from "@mui/material/Alert";
import AlertTitle from "@mui/material/AlertTitle";
import Button from "@mui/material/Button";
import Card from "@mui/material/Card";
import CardContent from "@mui/material/CardContent";
import Chip from "@mui/material/Chip";
import CircularProgress from "@mui/material/CircularProgress";
import Grid from "@mui/material/Grid";
import LinearProgress from "@mui/material/LinearProgress";
import Stack from "@mui/material/Stack";
import Typography from "@mui/material/Typography";
import MicIcon from "@mui/icons-material/Mic";
import MicOffIcon from "@mui/icons-material/MicOff";

/**
 * The live lecture room.
 *
 * Uses livekit-client directly, not @livekit/components-react: that package
 * ships its own stylesheet, and this app is pure MUI with no CSS.
 *
 * Two agents share the room with the student:
 *   Lecturer — speaks the premade script (TTS) and drives the slides
 *   Listener — hears the student, and interrupts the Lecturer when they speak
 */

type AgentState = "connecting" | "lecturing" | "listening" | "answering" | "ended";

const STATE_LABEL: Record<AgentState, string> = {
  connecting: "Connecting…",
  lecturing: "Lecturer speaking",
  listening: "Listening to you…",
  answering: "Answering your question",
  ended: "Lecture finished",
};

const STATE_COLOR: Record<AgentState, "default" | "primary" | "secondary" | "success"> = {
  connecting: "default",
  lecturing: "primary",
  listening: "secondary",
  answering: "secondary",
  ended: "success",
};

type Props = { lectureId: number };

export default function LectureRoom({ lectureId }: Props) {
  const [room] = useState(() => new Room({ adaptiveStream: true }));
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [muted, setMuted] = useState(false);
  const [agentState, setAgentState] = useState<AgentState>("connecting");
  const [slide, setSlide] = useState(1);
  const [week, setWeek] = useState<number | null>(null);
  const [title, setTitle] = useState("");
  const [attendance, setAttendance] = useState<{ status: string; lateMinutes: number } | null>(null);
  const [lastAnswer, setLastAnswer] = useState<{ question: string; answer: string; pages: number[] } | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const micRef = useRef<LocalAudioTrack | null>(null);

  const connect = useCallback(async () => {
    try {
      const res = await fetch(`/api/lecture/${lectureId}/token`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Could not join the lecture.");

      setWeek(data.lecture.week);
      setTitle(data.lecture.title);
      setAttendance(data.attendance);

      room
        .on(RoomEvent.TrackSubscribed, (track: RemoteTrack, _pub: RemoteTrackPublication) => {
          // The Lecturer's synthesized voice.
          if (track.kind === Track.Kind.Audio && audioRef.current) {
            track.attach(audioRef.current);
          }
        })
        .on(RoomEvent.DataReceived, (payload: Uint8Array) => {
          // Slide sync and status, sent by the voice worker.
          try {
            const message = JSON.parse(new TextDecoder().decode(payload));
            if (message.type === "slide" && typeof message.n === "number") setSlide(message.n);
            if (message.type === "state") setAgentState(message.state as AgentState);
            if (message.type === "answer") setLastAnswer(message.payload);
          } catch {
            // A malformed data message must never take the lecture down.
          }
        })
        .on(RoomEvent.Disconnected, () => setConnected(false));

      await room.connect(data.url, data.token);

      const mic = await createLocalAudioTrack();
      micRef.current = mic;
      await room.localParticipant.publishTrack(mic);

      setConnected(true);
      setAgentState("lecturing");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not join the lecture.");
    }
  }, [lectureId, room]);

  useEffect(() => {
    connect();
    return () => {
      room.disconnect();
    };
  }, [connect, room]);

  async function toggleMute() {
    const mic = micRef.current;
    if (!mic) return;
    // Muted means the Listener agent cannot hear us, so the lecture is never
    // interrupted — that is the whole point of the button.
    if (muted) {
      await mic.unmute();
      setMuted(false);
    } else {
      await mic.mute();
      setMuted(true);
    }
  }

  if (error) {
    return (
      <Stack spacing={2}>
        <Alert severity="error">
          <AlertTitle>Could not join</AlertTitle>
          {error}
        </Alert>
        <Button variant="contained" onClick={connect}>
          Try again
        </Button>
      </Stack>
    );
  }

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">
          {week ? `Week ${week} — ${title}` : "Lecture"}
        </Typography>
        <Grid container spacing={1}>
          <Grid>
            <Chip color={STATE_COLOR[agentState]} label={STATE_LABEL[agentState]} />
          </Grid>
          <Grid>
            <Chip variant="outlined" label={`slide ${slide}`} />
          </Grid>
          {attendance ? (
            <Grid>
              <Chip
                color={attendance.status === "late" ? "warning" : "success"}
                variant="outlined"
                label={
                  attendance.status === "late"
                    ? `joined ${attendance.lateMinutes} min late`
                    : "joined on time"
                }
              />
            </Grid>
          ) : null}
        </Grid>
      </Stack>

      {!connected ? <LinearProgress /> : null}

      <Card variant="outlined">
        <CardContent>
          {week ? (
            <iframe
              key={week}
              src={`/slides/week-${week}/index.html#/${slide}`}
              title={`Week ${week} slides`}
              width="100%"
              height="520"
              frameBorder="0"
            />
          ) : (
            <CircularProgress />
          )}
        </CardContent>
      </Card>

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Grid container spacing={2}>
              <Grid>
                <Button
                  variant="contained"
                  color={muted ? "error" : "primary"}
                  startIcon={muted ? <MicOffIcon /> : <MicIcon />}
                  onClick={toggleMute}
                  disabled={!connected}
                >
                  {muted ? "Unmute microphone" : "Mute microphone"}
                </Button>
              </Grid>
              <Grid>
                <Button
                  variant="outlined"
                  color="secondary"
                  onClick={() => room.disconnect()}
                  disabled={!connected}
                >
                  Leave lecture
                </Button>
              </Grid>
            </Grid>
            <Typography variant="body2" color="text.secondary">
              {muted
                ? "Your microphone is off. The lecturer will not be interrupted."
                : "Just speak — the lecturer will stop, answer from the book, and carry on."}
            </Typography>
          </Stack>
        </CardContent>
      </Card>

      {lastAnswer ? (
        <Card variant="outlined">
          <CardContent>
            <Stack spacing={1}>
              <Typography variant="overline" color="text.secondary">
                You asked
              </Typography>
              <Typography variant="body1">{lastAnswer.question}</Typography>
              <Typography variant="overline" color="text.secondary">
                Answer
              </Typography>
              <Typography variant="body1">{lastAnswer.answer}</Typography>
              {lastAnswer.pages?.length ? (
                <Grid container spacing={1}>
                  {lastAnswer.pages.map((page) => (
                    <Grid key={page}>
                      <Chip size="small" variant="outlined" label={`p. ${page}`} />
                    </Grid>
                  ))}
                </Grid>
              ) : null}
            </Stack>
          </CardContent>
        </Card>
      ) : null}

      {/* The Lecturer's voice. autoPlay so the lecture starts by itself. */}
      <audio ref={audioRef} autoPlay />
    </Stack>
  );
}
