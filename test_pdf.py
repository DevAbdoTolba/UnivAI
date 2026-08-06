import sys
from pathlib import Path

path = Path("uploads/S-2026-000009/collections/7/15/Rust_for_C_Programmers__Learn_how_to_embed_Rust_in_C_C_--_Mustafif_Khan_--_1_2023_--_BPB_Publications_--_9079930f1483520030ba6327f94ed98a_--_Anna_s_Archive.pdf").resolve()
print(f"Loading {path}")

import pymupdf
doc = pymupdf.open(str(path))
print(f"Opened. Pages: {len(doc)}")
