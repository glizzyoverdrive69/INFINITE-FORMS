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
| **Bin Finder** | Instant ranked search across every bin (and optionally every file name) in the Media Pool — jump anywhere in two keystrokes. Fuzzy and multi-word queries (`ep3 aud`, `bkgm` → Buckingham Palace), search as you type, Enter to open, and it switches to the Edit page so the jump is actually visible from Colour or Fairlight. Pinnable, with a compact mode that is just a search bar until you type, then expands to show results |
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

**Double-click `One Click Install Infinite Forms.command`.** It checks
every dependency (and tells you which ones are fatal versus which just
cost you a feature), validates the plugin file, copies it and the docx
helper into Resolve's Scripts folder, backs up any previous install, and
installs `python-docx` into whichever Python Resolve is using. Then
restart Resolve and launch **infinite_forms_plugin** from
Workspace > Scripts > Utility.

If macOS blocks the installer as coming from an unidentified developer,
right-click it > **Open** — Gatekeeper flags any downloaded script, and
you only clear it once.

See **[INSTALL.md](INSTALL.md)** for the full fresh-machine guide: the
prerequisites the installer can't handle for you (Resolve Studio, Python,
and the one scripting preference), the manual equivalent of every step,
the per-project assets each feature expects, and a troubleshooting table.

## Repository layout

```
infinite_forms_plugin.py      The plugin -- single file, no dependencies
                              beyond python-docx
One Click Install Infinite Forms.command
                              Double-click installer (macOS): dependency
                              checks, validate, install, python-docx.
                              Must keep its executable bit to stay
                              double-clickable
INSTALL.md                    Fresh-machine installation guide
scripts/
  install_python_docx.py      Installs python-docx into Resolve's Python,
                              run from inside Resolve
docs/
  ui_mockup.html              Interactive HTML mockup of the panel UI
```

## Releasing an update

To publish a new version:

1. Bump `BUILD_TAG` at the top of `infinite_forms_plugin.py`
2. Set the `VERSION` file to the exact same string
3. Commit and push both together

Both steps matter: the check compares the repo's `VERSION` against the
installed `BUILD_TAG`, so a release that bumps only one of them is
invisible to everyone.

There are three ways an installed copy finds out:

- **Automatically at launch** — every time the panel opens it checks once,
  with a 3-second timeout so a slow network can't delay the window. The
  result always lands in the panel log, including "up to date", so you can
  see that it ran. Anything you have to act on — a new build, a private
  repo, missing certificates — also pops the same dialog the button shows,
  once the panel is up. Being offline is reported to the Console only, so a
  machine that's offline on purpose isn't nagged every launch. Set
  `UPDATE_STARTUP_DIALOG = False` to keep launch findings in the log only.
- **Check for Update** at the bottom of the panel — the same check on
  demand, with a fuller explanation in a dialog. It never touches the
  installed file; it just tells you to download the project and re-run
  the installer.
- **The Update button** in the panel header — appears only when the launch
  check found a new build, and installs in place. Downloads are validated
  (size + full compile + end-of-file marker) before replacing anything,
  and the previous version is kept as a `.bak` alongside.

All three need `UPDATE_REPO` (top of the plugin file) pointing at a
**public** repo. While the repo is private, GitHub answers 404 to an
unauthenticated request, and both the launch check and the button report
**"repo set to private"**.

## Notes

- The panel prints staged startup banners to the Console
  (`Workspace > Console`, Py3 tab) — if it ever fails to open, the last
  banner printed identifies the failure stage.
- Bin label colours aren't scriptable in the Resolve API; the Sort
  feature colours all clips and tells you when the theme folders need a
  manual right-click > colour.
