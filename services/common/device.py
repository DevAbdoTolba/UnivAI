"""Where the voice models run: GPU if we have one, CPU otherwise.

Set DEVICE in .env to force it:  auto (default) | cuda | cpu

The RTX-class laptop GPUs this runs on have ~6 GB, which comfortably holds
XTTS-v2 (~2 GB) and a small/base Whisper (~1 GB) at the same time.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

_PREFERENCE = os.getenv("DEVICE", "auto").strip().lower()


def cuda_available() -> bool:
    try:
        import torch

        return bool(torch.cuda.is_available())
    except Exception:
        return False


def device() -> str:
    """'cuda' or 'cpu'."""
    if _PREFERENCE == "cpu":
        return "cpu"
    if _PREFERENCE == "cuda":
        if not cuda_available():
            print("[device] DEVICE=cuda but no usable CUDA build of torch — falling back to CPU")
            return "cpu"
        return "cuda"
    return "cuda" if cuda_available() else "cpu"


def whisper_settings() -> tuple[str, str]:
    """(device, compute_type) for faster-whisper / CTranslate2."""
    if device() == "cuda":
        return "cuda", os.getenv("STT_COMPUTE_TYPE", "float16")
    return "cpu", os.getenv("STT_COMPUTE_TYPE", "int8")


def describe() -> str:
    if device() == "cpu":
        return "CPU"
    try:
        import torch

        return f"GPU ({torch.cuda.get_device_name(0)})"
    except Exception:
        return "GPU"
