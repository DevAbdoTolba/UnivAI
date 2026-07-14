"""The live lecture: one worker process, two agent identities in the LiveKit room.

    Lecturer  publishes the TTS audio track and drives the slides
    Listener   subscribes to the student's mic, runs VAD + STT, and interrupts

State machine (exactly as specified):

    LECTURING    stream script.json through TTS, sentence by sentence.
                 Each segment sends {type:"slide", n} so the Slidev iframe flips.
                 Student speaks (VAD >= 300 ms) -> INTERRUPTED

    INTERRUPTED  stop TTS immediately, remember the position (segment + sentence)
                 run STT until the student stops (silence ~800 ms) -> ANSWERING

    ANSWERING    question -> RAG (MCP) -> tiny LLM -> <=3 sentences, cited
                 speak the answer, then resume LECTURING from the remembered
                 sentence, restarting that sentence from its beginning.

    MUTED        the student's mic is muted client-side, so VAD never fires and
                 the lecture is never interrupted.

Run:  python services/voice-agent/worker.py dev
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np
from dotenv import load_dotenv
from livekit import agents, rtc

from common.device import whisper_settings, describe  # noqa: E402
from qa import answer_question  # noqa: E402
from tts import load_engine  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

LECTURES_DIR = ROOT / "lectures"
STT_MODEL_SIZE = os.getenv("STT_MODEL_SIZE", "base")

SPEECH_TRIGGER_MS = 300     # this much speech from the student = a barge-in
SILENCE_END_MS = 800        # this much silence = they have finished asking
REVIEW_TIMEOUT_S = 120      # how long we hold the lecture while they edit the transcript


# ---------------------------------------------------------------- lecture script


@dataclass
class Position:
    """Where the Lecturer is in the script, so it can resume after a question."""

    segment: int = 0
    sentence: int = 0


@dataclass
class Lecture:
    week: int
    title: str
    segments: list[dict]
    position: Position = field(default_factory=Position)

    @staticmethod
    def load(week: int) -> "Lecture":
        script = json.loads((LECTURES_DIR / f"week-{week}" / "script.json").read_text("utf-8"))
        return Lecture(week=week, title=script["title"], segments=script["segments"])


def split_sentences(text: str) -> list[str]:
    """TTS speaks a sentence at a time: it lets a barge-in cut in sooner, and it
    gives us a clean point to resume from."""
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]


# ---------------------------------------------------------------- the worker


class LectureSession:
    def __init__(self, room: rtc.Room, lecture: Lecture) -> None:
        self.room = room
        self.lecture = lecture
        self.tts = load_engine()

        # Engines differ: Piper is 22.05 kHz, XTTS is 24 kHz. Publishing at the
        # wrong rate does not fail — it just makes the lecturer sound wrong.
        self.sample_rate = self.tts.sample_rate
        self.source = rtc.AudioSource(self.sample_rate, 1)
        self.track = rtc.LocalAudioTrack.create_audio_track("lecturer", self.source)

        self.interrupted = asyncio.Event()   # set by the Listener on a barge-in
        # What Whisper heard. It is shown in the browser for the student to correct.
        self.heard: asyncio.Queue[str] = asyncio.Queue()
        # What the student actually confirmed (possibly edited). "" means they cancelled.
        self.confirmed: asyncio.Queue[str] = asyncio.Queue()
        self.speaking = False
        self.closed = False          # the student left; stop talking to an empty room

    # -- outbound messages to the browser --------------------------------------

    async def send(self, message: dict) -> None:
        if self.closed:
            return
        try:
            await self.room.local_participant.publish_data(
                json.dumps(message).encode("utf-8"), reliable=True
            )
        except Exception:
            self.closed = True

    # -- speaking ---------------------------------------------------------------

    async def speak(self, text: str, interruptible: bool = True) -> bool:
        """Speak one sentence. Returns False if the student cut in mid-sentence."""
        self.speaking = True
        try:
            for chunk in self.tts.synthesize(text):
                if interruptible and self.interrupted.is_set():
                    return False  # drop the rest of this sentence immediately
                if self.closed:
                    return False
                pcm = (np.clip(chunk, -1.0, 1.0) * 32767).astype(np.int16)
                frame = rtc.AudioFrame(
                    data=pcm.tobytes(),
                    sample_rate=self.sample_rate,
                    num_channels=1,
                    samples_per_channel=len(pcm),
                )
                try:
                    await self.source.capture_frame(frame)
                except Exception as exc:
                    # The student closed the tab mid-sentence. Stop talking to an
                    # empty room rather than crashing the worker.
                    print(f"[lecture] room is gone, stopping: {exc}")
                    self.closed = True
                    return False
            return True
        finally:
            self.speaking = False

    # -- the state machine ------------------------------------------------------

    async def run(self) -> None:
        await self.room.local_participant.publish_track(self.track)
        await self.send({"type": "state", "state": "lecturing"})

        segments = self.lecture.segments
        position = self.lecture.position

        while position.segment < len(segments) and not self.closed:
            segment = segments[position.segment]

            # Flip the slide as the segment begins.
            if position.sentence == 0:
                await self.send({"type": "slide", "n": segment["slide"]})

            sentences = split_sentences(segment["text"])

            while position.sentence < len(sentences) and not self.closed:
                finished = await self.speak(sentences[position.sentence])

                if self.closed:
                    break
                if not finished:
                    # INTERRUPTED: the student spoke. Keep `position` exactly where
                    # it is, so we repeat this sentence from its start afterwards.
                    await self.handle_interruption()
                    await self.send({"type": "state", "state": "lecturing"})
                    await self.send({"type": "slide", "n": segment["slide"]})
                    continue

                position.sentence += 1

            position.segment += 1
            position.sentence = 0

        await self.send({"type": "state", "state": "ended"})

    async def handle_interruption(self) -> None:
        await self.send({"type": "state", "state": "listening"})

        try:
            heard = await asyncio.wait_for(self.heard.get(), timeout=20)
        except asyncio.TimeoutError:
            # They made a noise but never actually asked anything. Carry on.
            self.interrupted.clear()
            return

        # Nothing is asked on the student's behalf. We show them what we heard and
        # they send it, edit it first, or throw it away.
        await self.send({"type": "state", "state": "review"})
        await self.send({"type": "transcript", "text": heard})
        print(f"[lecture] heard: {heard!r} - waiting for the student to confirm")

        try:
            question = await asyncio.wait_for(self.confirmed.get(), timeout=REVIEW_TIMEOUT_S)
        except asyncio.TimeoutError:
            print("[lecture] no confirmation - resuming the lecture")
            await self.send({"type": "transcript", "text": None})
            self.interrupted.clear()
            return

        if not question.strip():          # they cancelled
            print("[lecture] question cancelled")
            self.interrupted.clear()
            return

        await self.send({"type": "state", "state": "answering"})
        print(f"[lecture] question: {question}")

        result = await answer_question(question, lecture_id=None)

        await self.send(
            {
                "type": "answer",
                "payload": {
                    "question": question,
                    "answer": result["answer"],
                    "pages": result["pages"],
                },
            }
        )

        # The answer itself is not interruptible: it is short by design.
        self.interrupted.clear()
        for sentence in split_sentences(result["answer"]):
            await self.speak(sentence, interruptible=False)

        self.interrupted.clear()


async def listen(session: LectureSession, track: rtc.RemoteAudioTrack) -> None:
    """The Listener agent: VAD for barge-in, faster-whisper for the question."""
    from faster_whisper import WhisperModel

    stt_device, compute_type = whisper_settings()
    model = WhisperModel(STT_MODEL_SIZE, device=stt_device, compute_type=compute_type)
    print(f"[listener] faster-whisper '{STT_MODEL_SIZE}' on {describe()} ({compute_type})")

    stream = rtc.AudioStream(track, sample_rate=16000, num_channels=1)
    buffer: list[np.ndarray] = []
    speech_ms = 0
    silence_ms = 0
    capturing = False

    async for event in stream:
        frame = event.frame
        samples = np.frombuffer(frame.data, dtype=np.int16).astype(np.float32) / 32768.0
        frame_ms = len(samples) / 16000 * 1000

        # Energy-based VAD. Cheap, and enough to decide "is the student talking".
        loud = float(np.sqrt(np.mean(samples**2))) > 0.02

        if loud:
            speech_ms += frame_ms
            silence_ms = 0
        else:
            silence_ms += frame_ms

        # A muted mic publishes no audio at all, so we simply never get here —
        # that is exactly why the mute button protects the lecture.
        if not capturing and speech_ms >= SPEECH_TRIGGER_MS:
            capturing = True
            session.interrupted.set()   # cuts the Lecturer off mid-sentence
            print("[listener] barge-in")

        if capturing:
            buffer.append(samples)

            if silence_ms >= SILENCE_END_MS:
                audio = np.concatenate(buffer) if buffer else np.zeros(1, dtype=np.float32)
                buffer, capturing, speech_ms, silence_ms = [], False, 0, 0

                transcribed, _info = model.transcribe(audio, language="en")
                text = " ".join(seg.text.strip() for seg in transcribed).strip()

                if text:
                    await session.heard.put(text)
                else:
                    session.interrupted.clear()

        if not capturing and silence_ms > 1000:
            speech_ms = 0


async def entrypoint(ctx: agents.JobContext) -> None:
    await ctx.connect()

    # Room names are lecture-week-N, so the week is the source of truth here.
    week = int(ctx.room.name.rsplit("-", 1)[-1])
    lecture = Lecture.load(week)
    print(f"[lecture] week {week}: {lecture.title} ({len(lecture.segments)} segments)")

    session = LectureSession(ctx.room, lecture)

    @ctx.room.on("track_subscribed")
    def on_track(track: rtc.Track, *_: object) -> None:
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            asyncio.create_task(listen(session, track))

    @ctx.room.on("data_received")
    def on_data(packet: rtc.DataPacket) -> None:
        # The student pressed Send (possibly after editing) or Cancel.
        try:
            message = json.loads(packet.data.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return
        if message.get("type") == "question":
            session.confirmed.put_nowait(str(message.get("text", "")))
        elif message.get("type") == "cancel":
            session.confirmed.put_nowait("")

    await session.run()


if __name__ == "__main__":
    agents.cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
