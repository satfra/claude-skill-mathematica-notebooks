# Claude skill: mathematica-notebook

A [Claude](https://claude.com/claude-code) skill for authoring and editing [Wolfram Mathematica](https://www.wolfram.com/mathematica/) notebooks (`.nb` files) from natural-language requests.

Ask Claude for a notebook — "scaffold me a notebook that derives the Euler–Lagrange equations for a simple pendulum" — and it produces a real, unevaluated `.nb` file structured with `Title` / `Section` / `Text` / `Input` cells that you can open in the Wolfram frontend and step through with Shift-Enter.

## What it does

- **Create** new `.nb` files from a structured cell specification — proper Wolfram serialization, no hand-written `Notebook[{…}]` gymnastics.
- **Extract** cells from an existing `.nb` back to a clean JSON form you (or Claude) can transform and write back — so Claude can refactor code inside a notebook without breaking its structure.
- **Round-trip safe**: plain-string Input/Code cells extract to the same JSON they were written from; complex cells (typeset math, graphics) come through as raw Wolfram expressions and pass through untouched.

## Prerequisites

A local Wolfram kernel. The bundled wrapper probes for one automatically:

1. `wolframscript` (recommended — comes with [Wolfram Engine](https://www.wolfram.com/engine/), which is free for developers)
2. `wolfram` (command-line kernel, Wolfram Desktop / Mathematica installations)
3. `math` (legacy kernel name)

On macOS, the wrapper also looks in `/Applications/Mathematica.app/Contents/MacOS/` and similar app-bundle locations. The **standalone Mathematica front-end alone is not enough** — you need a command-line kernel.

## Repo layout

```text
<repo>/
├── README.md                       ← this file
└── mathematica-notebook/           ← the skill itself (install this)
    ├── SKILL.md
    └── scripts/
        ├── run_wolfram.sh
        └── nb_tool.wls
```

## Installation

Clone the repo, then copy (or symlink) the `mathematica-notebook/` subfolder into your Claude skills directory:

```bash
git clone https://github.com/<you>/mathematica-notebook-skill.git
cp -r mathematica-notebook-skill/mathematica-notebook ~/.claude/skills/
chmod +x ~/.claude/skills/mathematica-notebook/scripts/run_wolfram.sh
```

Or, if you prefer a packaged install, grab the `.skill` artifact from the Releases page and install via your Claude harness's plugin mechanism.

## Quick examples

Ask Claude things like:

- *"Put together a notebook that derives the equations of motion for a simple pendulum via the Euler–Lagrange formalism, plus the small-angle limit. Save as `pendulum.nb`."*
- *"I need a notebook doing slow-roll inflation checks for a `φ²` and a `φ⁴` potential — integrate the background ODEs with `NDSolve` and extract `t_end` where `ε=1`. Call it `inflaton.nb`."*
- *"Read `gamma_traces.nb`, keep the Weyl-representation setup, but rewrite every trace computation to use `Signature` instead of the explicit Levi-Civita lookup."*

## How it works

Claude authors a flat list of cell specs as JSON, passes them to the bundled Wolfram script, and the kernel builds a real `Notebook[{Cell[…], …}]` expression and writes it out with `Put`. `Input`/`Code`/`Program` cell bodies are wrapped in `BoxData[…]` so the frontend renders them as formatted code; other styles (Title, Section, Text, …) take plain strings.

```text
mathematica-notebook/
├── SKILL.md              ← instructions Claude reads when the skill triggers
├── README.md             ← you are here
└── scripts/
    ├── run_wolfram.sh    ← bash wrapper: probes for a Wolfram kernel
    └── nb_tool.wls       ← Wolfram Language script: create / extract
```

## Cell spec format

```json
{
  "cells": [
    {"type": "Title",   "content": "Simple Pendulum"},
    {"type": "Section", "content": "Setup"},
    {"type": "Text",    "content": "Generalized coordinate: theta(t)."},
    {"type": "Input",   "content": "L = (1/2) m l^2 theta'[t]^2 - m g l (1 - Cos[theta[t]])"}
  ]
}
```

Supported cell types (typical hierarchy):

`Title` · `Chapter` · `Section` · `Subsection` · `Subsubsection` · `Subsubsubsection` · `Text` · `Input` · `Code` · `Item` · `ItemNumbered` · `Program` · `Message` · `Caption` · `PageBreak`

Optional `"raw": true` parses `"content"` as a Wolfram expression instead of a string — useful for typeset math (`TextData`, `BoxData[FormBox[…]]`) and other frontend-structural content.

## Command-line usage

The wrapper can also be invoked directly, independently of Claude:

```bash
# Create an .nb from a JSON cell list
./scripts/run_wolfram.sh create cells.json out.nb

# Extract cells from an .nb back to JSON
./scripts/run_wolfram.sh extract in.nb cells.json
```

This makes the skill useful as a plain CLI tool too — e.g., for generating notebooks from other scripts or templating pipelines.

## Troubleshooting

- **"No Wolfram kernel found on PATH"** — Install [Wolfram Engine](https://www.wolfram.com/engine/) (free) or use a full Wolfram Desktop / Mathematica install and ensure `wolframscript`, `wolfram`, or `math` is on your `$PATH`. The standalone frontend (`Mathematica.app` / `Mathematica.exe`) is not a kernel.
- **"file does not parse as a valid Wolfram Notebook expression"** — usually the `.nb` was hand-edited and its expression syntax was damaged. Open it in the Wolfram frontend, save, and re-try.
- **Sandboxed environments** — if Claude's bash is restricted from running the wrapper, it falls back to writing the `Notebook[{…}]` expression directly (see SKILL.md "If the wrapper can't be executed"). The user can re-run the wrapper on the saved `cells.json` once wrapper access is granted.
