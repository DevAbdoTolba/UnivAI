"""One sentence splitter for everyone who touches the lecture script.

The worker speaks a sentence at a time (barge-ins cut in sooner, resume points
stay clean), and the pre-renderer must cut the SAME way or the audio files and
the live script drift apart.
"""

from __future__ import annotations

import re


def split_sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]
