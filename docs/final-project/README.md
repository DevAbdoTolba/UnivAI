# UnivAI final-project documentation package

This directory contains the formal Group G3 project-discussion report and its
reproducible evidence assets.

## Deliverables

- `UnivAI_Final_Project_Documentation.docx` - byte-reproducible generated Word
  report with updateable fields.
- `UnivAI_Final_Project_Documentation_Field_Updated.docx` - Word-paginated copy
  with the TOC and page fields refreshed (55 pages at the evidence freeze).
- `UnivAI_Final_Project_Documentation_Field_Updated.pdf` - verified 55-page PDF
  export of the field-updated Word copy.
- `UnivAI_Final_Project_Documentation.md` - generated editable Markdown mirror.
- `evaluation/llm_evaluation_dataset.csv` - 72 LLM/RAG cases with proposed
  ground truth pending two-person adjudication.
- `evaluation/source_fixtures.json` - synthetic, copyright-safe evidence corpus.
- `evaluation/run_evaluation.py` - strict offline validator and evidence scorer.
- `evaluation/CAPTURE_PROTOCOL.md` - external ingestion, execution, review, and
  evidence-sealing procedure.
- `evaluation/model_outputs_v2_template.csv` and `model_output_schema.json` -
  authoritative captured-output contract.
- `evaluation/citation_mapping_template.json` and `run_metadata_template.json` -
  templates for stable production citation identity and reproducible run metadata.
- `evaluation/manual_test_protocols.csv` - UAT, usability, accessibility, and
  penetration scripts.
- `figures/` - rendered architecture, DFD, ERD, sequence, LangGraph, RAG,
  security, test-strategy, and Gantt diagrams.
- `diagrams/diagrams.md` - editable Mermaid equivalents of the main figures.
- `references/` - the two internal project sources cited by the report.
- `build_document.py` - byte-reproducible report and figure generator.

`build_document.py` plus `evaluation_data.py` are the source of truth for the
generated DOCX, Markdown, figures, dataset, protocols, and manifest. Rebuilding
overwrites those generated files. `diagrams/diagrams.md` contains editable
Mermaid equivalents for discussion and review; the PNG figures are rendered by
the Python generator rather than from Mermaid.

## Rebuild

From the `UnivAI/` directory:

```powershell
uv pip install --python .venv/Scripts/python.exe python-docx matplotlib pillow
.venv/Scripts/python.exe docs/final-project/build_document.py
```

The generator performs basic checks for nonblank unique case IDs, minimum case
count, valid image files, required Word package members, embedded figures,
alternative text, bibliography hyperlinks, and key report text. Run the strict
evaluator below for exact fields, category distribution, gates, and hashes.

## LLM evaluation usage

The evaluator is offline: it never calls UnivAI or a model. First validate the
designed specification:

```powershell
.venv/Scripts/python.exe docs/final-project/evaluation/run_evaluation.py --validate-only
.venv/Scripts/python.exe docs/final-project/evaluation/validate_manual_results.py docs/final-project/evaluation/manual_test_protocols.csv
.venv/Scripts/python.exe -m unittest discover -s docs/final-project/evaluation -p "test_*.py" -v
```

`SPEC VALID` confirms only the 72-case/ten-category schema. The current labels
are pending two-person gold adjudication, so the runner intentionally prints
`SPEC ONLY` and blocks scoring and release. After adjudication, follow
`evaluation/CAPTURE_PROTOCOL.md` to ingest the fixed corpus, create a captured
citation mapping, execute the cases externally, perform two-person output
review, and seal run metadata. Then run:

The package supplies the offline specification, contracts, scorer, and capture
procedure. A deterministic source-document renderer and a product-specific
capture adapter are external execution prerequisites; they are not included or
claimed as completed evidence in this package.

```powershell
.venv/Scripts/python.exe docs/final-project/evaluation/run_evaluation.py `
  --outputs docs/final-project/evaluation/model_outputs.csv `
  --citation-map docs/final-project/evaluation/citation_mapping.json `
  --run-metadata docs/final-project/evaluation/run_metadata.json
```

All 67 `required` cases must resolve to PASS for a release claim. The five
currently unsupported language/dialect cases are `exploratory`: their results
are still reported but do not block the gate. Citation identity and hashes are
checked automatically; semantic correctness and claim entailment are never
claimed as automated and require named, dated reviewers.

## Evidence labels

The report distinguishes verified automated evidence from designed manual
protocols. Human UAT, usability sessions, accessibility review, and manual
penetration testing are not marked as passed until a named tester records dated
evidence.

## Before institutional submission

Open the DOCX in desktop Word, update all fields, inspect every page, then save
and export the required PDF. Recreate the field-updated copy after any source
rebuild. Confirm the supervisor/mentor, student IDs,
track/intake, approval/signature page, institutional branding, and individual
RACI assignments with ITI; the repository does not contain approved values, so
the generator does not invent them.
