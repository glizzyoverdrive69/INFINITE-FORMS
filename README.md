# Infinite Forms

**Tools to work smarter, not harder.**

A native DaVinci Resolve Studio automation panel for tourism video
post-production. Built as a UIManager plugin — one floating panel, seven
tools, designed around a real studio pipeline (writer's scripts in,
assembled timelines out).

## Features

| Tool | What it does |
|---|---|
| **Auto Lower Thirds** | Reads clips across V1–V4 and stamps a templated Text+ lower third for each on V5, labelled from the clip's location bin |
| **Bin Finder** | Instant ranked search across every bin (and optionally every file name) in the Media Pool — jump anywhere in two keystrokes. Pinnable, collapsible |
| **Colour Grading Prep** | Assigns every clip on a timeline to the right client colour group and verifies timeline format/colour settings |
| **Mid/Short Form Assembly** | Parses a writer's script (.docx), matches its locations against the Media Pool, and assembles a new timeline: approved Clip Asset Package clips (exact trims + grades) grouped per script location, with per-group lower thirds. Two versions: **Lisa** (package + remainder of each location's bins) and **Maggie** (package clips only). Unused package clips land together at the end |
| **Rename Video & Audio Tracks** | Applies the standard track layout (VIDEO A/B, GRAPHICS, CAM AUDIO, MUSIC 1/2, TEMP VO, HUMAN VO, SFX 1/2, MASTER) in one click |
| **Replace Camera Audio** | Restores embedded camera audio for every clip on V1 to a dedicated mono track, frame-accurate |
| **Sort by Shoot Notes** | Parses a shoot-notes .docx (themes → POIs) and reorganises a destination's location bins into Theme/POI folder hierarchies, colour-coding every clip per theme — with a preview mode and a missed-POI checklist |

The location matching throughout is fuzzy and battle-tested: misspellings
("Greenwhich", "Buckingam palace"), spacing drift ("China town" /
"Chinatown"), accented names, abbreviations, and sub-locations rolling up
to their parent POI.

## Requirements

- **DaVinci Resolve Studio** (the free edition lacks the UI toolkit)
- **macOS** with [python.org](https://python.org) Python 3 installed
- **python-docx** in Resolve's Python — a one-click installer script is
  included (`scripts/install_python_docx.py`)

## Installation

See **[INSTALL.md](INSTALL.md)** for the full fresh-machine guide,
including the per-project assets each feature expects and a
troubleshooting table.

The short version: copy `infinite_forms_plugin.py` and
`scripts/install_python_docx.py` into
`~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/`,
restart Resolve, run the installer script once from Workspace > Scripts,
then launch **infinite_forms_plugin** from the same menu.

## Repository layout

```
infinite_forms_plugin.py      The plugin -- single file, no dependencies
                              beyond python-docx
INSTALL.md                    Fresh-machine installation guide
scripts/
  install_python_docx.py      Installs python-docx into Resolve's Python,
                              run from inside Resolve
docs/
  ui_mockup.html              Interactive HTML mockup of the panel UI
```

## Releasing an update

The plugin self-updates from this repo. To publish a new version:

1. Bump `BUILD_TAG` at the top of `infinite_forms_plugin.py`
2. Set the `VERSION` file to the exact same string
3. Commit and push both together

Installed plugins (with `UPDATE_REPO` configured) will show an Update
button in the panel header on next launch. Downloads are validated
(size + full compile) before replacing anything, and the previous
version is kept as a `.bak` alongside.

## Notes

- The panel prints staged startup banners to the Console
  (`Workspace > Console`, Py3 tab) — if it ever fails to open, the last
  banner printed identifies the failure stage.
- Bin label colours aren't scriptable in the Resolve API; the Sort
  feature colours all clips and tells you when the theme folders need a
  manual right-click > colour.
