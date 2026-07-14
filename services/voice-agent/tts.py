"""Local TTS for the Lecturer agent.

Measured on this project's dev machine (RTX 3060 laptop, 6 GB):

    XTTS-v2 (Coqui)   0.55x realtime  -- 10 s of compute for 5.5 s of speech
    Piper (lessac)     11x realtime   -- first audio in ~0.2 s

XTTS is slower than speech even on the GPU, so a lecture read by it stalls
constantly. Piper is the default for that reason. XTTS remains selectable
(TTS_ENGINE=coqui) because it sounds better, and the latency gate below reports
the real number rather than letting it fail quietly in a demo.
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Iterator

import numpy as np
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.device import device, describe  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

# XTTS asks you to accept its licence on stdin. A background worker has no stdin,
# so without this it hangs forever with no output — which is exactly what happened.
os.environ.setdefault("COQUI_TOS_AGREED", "1")

TTS_ENGINE = os.getenv("TTS_ENGINE", "piper").lower()
LATENCY_GATE_S = float(os.getenv("TTS_LATENCY_GATE_S", "2.0"))
PIPER_MODEL = os.getenv("PIPER_MODEL", "models/piper/en_US-lessac-medium.onnx")


class TTSEngine:
    """Yields float32 PCM chunks at self.sample_rate."""

    name = "none"
    sample_rate = 22050

    def synthesize(self, text: str) -> Iterator[np.ndarray]:
        raise NotImplementedError


class PiperTTS(TTSEngine):
    name = "piper"

    def __init__(self) -> None:
        from piper import PiperVoice

        model = ROOT / PIPER_MODEL if not Path(PIPER_MODEL).is_absolute() else Path(PIPER_MODEL)
        if not model.exists():
            raise RuntimeError(
                f"Piper voice not found at {model}. Download one from "
                "huggingface.co/rhasspy/piper-voices and set PIPER_MODEL."
            )

        self.voice = PiperVoice.load(str(model), use_cuda=device() == "cuda")
        # Piper is ~11x realtime on CPU already; CUDA only helps if onnxruntime-gpu
        # is installed, and it is not required.
        self.sample_rate = self.voice.config.sample_rate
        print(f"[tts] Piper '{model.name}' ready ({self.sample_rate} Hz)")

    def synthesize(self, text: str) -> Iterator[np.ndarray]:
        for chunk in self.voice.synthesize(text):
            yield chunk.audio_int16_array.astype(np.float32) / 32768.0


class CoquiTTS(TTSEngine):
    name = "coqui-xtts-v2"
    sample_rate = 24000

    def __init__(self) -> None:
        from TTS.api import TTS as CoquiAPI

        self.model = CoquiAPI(
            "tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False
        ).to(device())
        print(f"[tts] XTTS-v2 loaded on {describe()}")
        self.speaker = os.getenv("TTS_SPEAKER", "Ana Florence")
        self.language = os.getenv("TTS_LANGUAGE", "en")

    def synthesize(self, text: str) -> Iterator[np.ndarray]:
        wav = np.asarray(
            self.model.tts(text=text, speaker=self.speaker, language=self.language),
            dtype=np.float32,
        )
        # Hand the room ~100 ms at a time so a barge-in can cut in quickly.
        frame = self.sample_rate // 10
        for start in range(0, len(wav), frame):
            yield wav[start : start + frame]


def _time_to_first_chunk(engine: TTSEngine) -> float:
    started = time.perf_counter()
    for _ in engine.synthesize("Latency check."):
        return time.perf_counter() - started
    return float("inf")


def load_engine() -> TTSEngine:
    """Load the configured engine and hold it to the latency gate."""
    engine: TTSEngine = CoquiTTS() if TTS_ENGINE == "coqui" else PiperTTS()

    latency = _time_to_first_chunk(engine)
    print(f"[tts] {engine.name}: time-to-first-audio {latency:.2f}s (gate {LATENCY_GATE_S}s)")

    if latency > LATENCY_GATE_S and engine.name != "piper":
        print(
            f"[tts] GATE FAILED — {engine.name} cannot keep up with live speech on this "
            f"machine. Falling back to Piper. Set TTS_ENGINE=piper to make it permanent."
        )
        try:
            return PiperTTS()
        except Exception as exc:
            print(f"[tts] Piper unavailable ({exc}); staying on {engine.name} despite the gate.")

    return engine
