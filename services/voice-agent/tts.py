"""Local streaming TTS for the Lecturer agent.

Coqui XTTS-v2 by default. XTTS on CPU can be too slow for real time, so the
engine is switchable in .env and the worker measures time-to-first-audio at
startup (the latency gate): if it exceeds LATENCY_GATE_S, it reports the number
and falls back to Piper, which is fast on CPU. The swap is never silent.
"""

from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Iterator

import numpy as np
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

TTS_ENGINE = os.getenv("TTS_ENGINE", "coqui").lower()
LATENCY_GATE_S = float(os.getenv("TTS_LATENCY_GATE_S", "2.0"))
SAMPLE_RATE = 24000


class TTSEngine:
    """Yields float32 PCM chunks at SAMPLE_RATE, sentence by sentence."""

    name = "none"

    def synthesize(self, text: str) -> Iterator[np.ndarray]:
        raise NotImplementedError


class CoquiTTS(TTSEngine):
    name = "coqui-xtts-v2"

    def __init__(self) -> None:
        from TTS.api import TTS as CoquiAPI  # provided by the maintained `coqui-tts` package

        self.model = CoquiAPI("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False)
        self.speaker = os.getenv("TTS_SPEAKER", "Ana Florence")
        self.language = os.getenv("TTS_LANGUAGE", "en")

    def synthesize(self, text: str) -> Iterator[np.ndarray]:
        wav = self.model.tts(text=text, speaker=self.speaker, language=self.language)
        audio = np.asarray(wav, dtype=np.float32)
        # Hand the room ~100 ms at a time so a barge-in can cut in quickly.
        frame = SAMPLE_RATE // 10
        for start in range(0, len(audio), frame):
            yield audio[start : start + frame]


class PiperTTS(TTSEngine):
    name = "piper"

    def __init__(self) -> None:
        from piper import PiperVoice

        model_path = os.getenv("PIPER_MODEL", "")
        if not model_path:
            raise RuntimeError("PIPER_MODEL is not set — download a .onnx voice from Piper")
        self.voice = PiperVoice.load(model_path)

    def synthesize(self, text: str) -> Iterator[np.ndarray]:
        for chunk in self.voice.synthesize_stream_raw(text):
            samples = np.frombuffer(chunk, dtype=np.int16).astype(np.float32) / 32768.0
            yield samples


def _measure_first_chunk(engine: TTSEngine) -> float:
    started = time.perf_counter()
    for _ in engine.synthesize("Latency check."):
        return time.perf_counter() - started
    return float("inf")


def load_engine() -> TTSEngine:
    """Load the configured engine, then run the latency gate on it."""
    if TTS_ENGINE == "piper":
        engine: TTSEngine = PiperTTS()
        print(f"[tts] engine={engine.name} (explicitly configured)")
        return engine

    engine = CoquiTTS()
    latency = _measure_first_chunk(engine)
    print(f"[tts] {engine.name}: time-to-first-audio = {latency:.2f}s (gate {LATENCY_GATE_S}s)")

    if latency > LATENCY_GATE_S:
        print(
            f"[tts] GATE FAILED: {engine.name} is too slow for real time on this machine. "
            f"Falling back to Piper. Set TTS_ENGINE=piper in .env to make this permanent."
        )
        try:
            piper = PiperTTS()
            print(f"[tts] engine={piper.name}")
            return piper
        except Exception as exc:
            print(f"[tts] Piper unavailable ({exc}); staying on {engine.name} despite the gate.")

    return engine
