# scripts/ — build helpers

| Script | Does | Run |
|---|---|---|
| `build-slides.mjs` | builds every `lectures/week-N/slides.md` Slidev deck into static pages at `UnivAI-app/public/slides/week-N/` | `node scripts/build-slides.mjs` (or `make slides`) |

The course builder runs this automatically at the end of a generation — run it
by hand only after editing a deck yourself. Slidev comes from the **root**
`package.json`.
