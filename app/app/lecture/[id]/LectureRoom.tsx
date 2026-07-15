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
import PanToolAltIcon from "@mui/icons-material/PanToolAlt";
import MicMeter from "./MicMeter";
import TranscriptReview from "./TranscriptReview";
import { formatLateness } from "@/lib/time";

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

type AgentState =
  | "connecting"
  | "lecturing"
  | "asking"
  | "listening"
  | "review"
  | "answering"
  | "ended";

const STATE_LABEL: Record<AgentState, string> = {
  connecting: "Connecting…",
  lecturing: "Lecturer speaking",
  asking: "Lecturer is asking you…",
  listening: "Listening to you…",
  review: "Paused — check your question",
  answering: "Answering your question",
  ended: "Lecture finished",
};

const STATE_COLOR: Record<AgentState, "default" | "primary" | "secondary" | "success"> = {
  connecting: "default",
  lecturing: "primary",
  asking: "secondary",
  listening: "secondary",
  review: "secondary",
  answering: "secondary",
  ended: "success",
};

type Props = { lectureId: number };

export default function LectureRoom({ lectureId }: Props) {
  const [room] = useState(() => new Room({ adaptiveStream: true }));
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // The mic starts MUTED: a student should never be broadcast without asking for it,
  // and an open mic on join would let a cough interrupt the lecture immediately.
  const [muted, setMuted] = useState(true);
  const [agentState, setAgentState] = useState<AgentState>("connecting");
  const [slide, setSlide] = useState(1);
  const [week, setWeek] = useState<number | null>(null);
  const [title, setTitle] = useState("");
  const [attendance, setAttendance] = useState<{ status: string; lateMinutes: number } | null>(null);
  const [lastAnswer, setLastAnswer] = useState<{ question: string; answer: string; pages: number[] } | null>(null);
  // What Whisper heard, waiting for the student to confirm or correct it.
  const [transcript, setTranscript] = useState<string | null>(null);
  // The raise-hand protocol: nobody unmutes unannounced. Raise your hand, the
  // lecturer finishes the sentence and asks you by name, THEN the mic unlocks.
  const [hand, setHand] = useState<"idle" | "raised" | "acked">("idle");
  // Chrome refuses to play audio on a page the user has not interacted with. The
  // lecture page auto-joins, so there is no gesture and the lecturer is silently
  // muted. LiveKit reports this, and room.startAudio() fixes it — but only from
  // inside a real click handler.
  const [audioBlocked, setAudioBlocked] = useState(false);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const slidesRef = useRef<HTMLIFrameElement | null>(null);
  const micRef = useRef<LocalAudioTrack | null>(null);
  const [mic, setMic] = useState<LocalAudioTrack | null>(null);

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
            audioRef.current.play().catch(() => setAudioBlocked(true));
          }
        })
        .on(RoomEvent.AudioPlaybackStatusChanged, () => {
          setAudioBlocked(!room.canPlaybackAudio);
        })
        .on(RoomEvent.DataReceived, (payload: Uint8Array) => {
          // Slide sync and status, sent by the voice worker.
          try {
            const message = JSON.parse(new TextDecoder().decode(payload));
            if (message.type === "slide" && typeof message.n === "number") setSlide(message.n);
            if (message.type === "state") {
              setAgentState(message.state as AgentState);
              // Reaching the end closes the lecture: it cannot be reopened.
              if (message.state === "ended") {
                fetch(`/api/lecture/${lectureId}/complete`, { method: "POST" });
              }
            }
            if (message.type === "answer") setLastAnswer(message.payload);
            if (message.type === "transcript") setTranscript(message.text ?? null);
            if (message.type === "hand") {
              if (message.state === "acked") setHand("acked");
              if (message.state === "lowered") {
                setHand("idle");
                // Hand time is over: whatever happened, the room goes quiet again.
                const track = micRef.current;
                if (track && !track.isMuted) {
                  track.mute().then(() => {
                    setMuted(true);
                    reply({ type: "mic", muted: true });
                  });
                }
              }
            }
          } catch {
            // A malformed data message must never take the lecture down.
          }
        })
        .on(RoomEvent.Disconnected, () => setConnected(false));

      await room.connect(data.url, data.token);

      const track = await createLocalAudioTrack({
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      });
      micRef.current = track;
      setMic(track);
      await track.mute();            // published, but silent until the student unmutes
      await room.localParticipant.publishTrack(track);

      setConnected(true);
      setAgentState("lecturing");
      if (!room.canPlaybackAudio) setAudioBlocked(true);
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

  // The Lecturer agent drives the deck: it sends {slide: n} as each segment
  // begins. Setting the hash on the iframe's own location navigates it; changing
  // the src attribute by hash alone often does not.
  useEffect(() => {
    const frame = slidesRef.current;
    if (!frame?.contentWindow) return;
    try {
      frame.contentWindow.location.hash = `/${slide}`;
    } catch {
      // Different origin (it is not) — fall back to reloading the frame.
      frame.src = `/slides/week-${week}/index.html#/${slide}`;
    }
  }, [slide, week]);

  async function reply(message: Record<string, unknown>) {
    await room.localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify(message)),
      { reliable: true }
    );
    if (message.type === "question" || message.type === "cancel") setTranscript(null);
  }

  async function raiseHand() {
    setHand("raised");
    await room.localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: "raise_hand" })),
      { reliable: true }
    );
  }

  async function toggleMute() {
    const track = micRef.current;
    if (!track) return;
    if (muted) {
      await track.unmute();
      setMuted(false);
      reply({ type: "mic", muted: false });
    } else {
      await track.mute();
      setMuted(true);
      reply({ type: "mic", muted: true });
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
                    ? `joined ${formatLateness(attendance.lateMinutes)}`
                    : "joined on time"
                }
              />
            </Grid>
          ) : null}
        </Grid>
      </Stack>

      {!connected ? <LinearProgress /> : null}

      {audioBlocked ? (
        <Alert
          severity="warning"
          action={
            <Button
              color="inherit"
              variant="outlined"
              onClick={async () => {
                await room.startAudio();
                await audioRef.current?.play().catch(() => undefined);
                setAudioBlocked(!room.canPlaybackAudio);
              }}
            >
              Enable sound
            </Button>
          }
        >
          Your browser has blocked the lecturer&apos;s voice until you click.
        </Alert>
      ) : null}

      <Card variant="outlined">
        <CardContent>
          {week ? (
            <iframe
              key={week}
              ref={slidesRef}
              src={`/slides/week-${week}/index.html#/1`}
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

      <TranscriptReview
        transcript={transcript}
        onSend={(question) => reply({ type: "question", text: question })}
        onCancel={() => reply({ type: "cancel" })}
      />

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <MicMeter track={mic} muted={muted} />

            <Grid container spacing={2}>
              <Grid>
                <Button
                  variant="contained"
                  color="secondary"
                  startIcon={<PanToolAltIcon />}
                  onClick={raiseHand}
                  disabled={!connected || hand !== "idle"}
                >
                  {hand === "raised"
                    ? "Hand raised…"
                    : hand === "acked"
                      ? "Lecturer is waiting"
                      : "Raise hand"}
                </Button>
              </Grid>
              <Grid>
                <Button
                  variant="contained"
                  color={muted ? "error" : "primary"}
                  startIcon={muted ? <MicOffIcon /> : <MicIcon />}
                  onClick={toggleMute}
                  disabled={!connected || (muted && hand !== "acked")}
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
              {hand === "acked"
                ? "The lecturer asked for you — unmute and ask your question."
                : hand === "raised"
                  ? "Hand raised. The lecturer will finish the sentence and ask you."
                  : muted
                    ? "Raise your hand to ask a question — the unmute button unlocks when the lecturer calls on you."
                    : "Ask your question — when you stop talking you can review what we heard."}
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
