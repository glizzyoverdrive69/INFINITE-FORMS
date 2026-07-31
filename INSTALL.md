# Infinite Forms — Fresh Mac Installation Guide

Everything needed to get the Infinite Forms plugin running on a brand-new
macOS machine, in order. Allow ~30 minutes plus download times.

---

## What you need

| Component | Why | Source |
|---|---|---|
| DaVinci Resolve **Studio** | The plugin's UI toolkit (UIManager) is not in the free version | blackmagicdesign.com (or your dongle/license) |
| Python 3 (python.org installer) | Resolve on macOS uses an external Python for scripting — it does not bundle one | python.org/downloads |
| `infinite_forms_plugin.py` | The plugin itself | from this project |
| `install_python_docx.py` | One-click installer for the docx library, run from inside Resolve | from this project |

---

## Step 1 — Install DaVinci Resolve Studio

Install and activate Studio (license key or dongle). Launch it once so it
creates its support folders, then quit.

**Check:** the splash screen says "DaVinci Resolve **Studio**". If it just
says "DaVinci Resolve", the plugin's window toolkit won't exist.

## Step 2 — Install Python

Download the latest Python 3 **macOS installer from python.org** and run it
with default options. This installs the "framework" Python that Resolve
detects automatically.

Note: Homebrew Python also exists in the world, but the python.org framework
install is the one this setup was validated against — use that one.

## Step 3 — Enable scripting in Resolve

Open Resolve → **DaVinci Resolve menu > Preferences > General** →
set **External scripting using** to **Local** → Save, and restart Resolve
if prompted.

## Step 4 — Install the plugin file

The target folder (create the final `Utility` folder if it doesn't exist):

```
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

The `Library` folder is hidden by default: in Finder, click the **Go** menu,
hold **Option**, and Library appears — or use Go > Go to Folder and paste the
path above.

Copy both files in:
- `infinite_forms_plugin.py`
- `install_python_docx.py`

(If a file was downloaded as `.txt`, rename it to end in `.py`. macOS may
warn about changing the extension — confirm it.)

**Restart Resolve** — it only scans the Scripts folders at launch.

## Step 5 — Install the docx library

The Mid/Short Form Assembly and Sort by Shoot Notes features read `.docx`
files and need the `python-docx` library installed into the same Python
Resolve uses. The installer script handles the "same Python" part for you:

1. In Resolve, open any project.
2. **Workspace > Console** (click the **Py3** button at the top).
3. **Workspace > Scripts > Utility > install_python_docx** — output streams
   into the Console; the first run takes a minute or two.
4. It must end with: `SUCCESS: python-docx is installed and visible to Resolve.`

If it ends with anything else, copy the whole Console output and send it to
Claude. (Lines like `log4cxx: No appender could be found...` are Resolve's
own internal noise — always safe to ignore, here and everywhere.)

## Step 6 — First launch

**Workspace > Scripts > Utility > infinite_forms_plugin**

The Infinite Forms panel should open: gold wordmark, six feature buttons
(Replace Camera Audio, Auto Lower Thirds, Mid/Short Form Assembly, Colour
Grading Prep, Rename Video & Audio Tracks, Sort by Shoot Notes, Bin Finder),
and a log box reading "Ready."

Quick smoke test that costs nothing: click **Bin Finder** — it should index
your bins instantly and let you jump to one.

---

## Per-project assets the features expect

These live in each Resolve **project** (or your template project), not on
the computer — set them up once in the house template and every job inherits
them:

- **`TM_LOWER_LEFT_THIRD_TEMPLATE`** — a Text+ title clip in the Media Pool
  with exactly that name, containing a Text+ node named `Template`. Used by
  Auto Lower Thirds and the assembly's per-group titles. Without it, those
  features log that titles were skipped and carry on.
- **Colour groups `CRM - Expedia` and `CRM - Skyscanner`** — with their
  pre/post-clip group grades set up by the colourist. Colour Grading Prep
  creates them empty if missing, but the grades themselves can't be scripted.
- **`.drx` clip grades (optional)** — when a per-client clip-grade still
  exists, export it from the Gallery and put its path into
  `CLIENT_COLOR_PRESETS` near the top of the plugin file.
- **`RAW-FILES` bin** — Sort by Shoot Notes looks for a bin with this name
  and lists its subfolders as destinations.
- **Documents as `.docx`** — writer's scripts and shoot notes must be Word
  files. Google Docs: File > Download > Microsoft Word. Apple Pages:
  File > Export To > Word. (Plain-text formats like CSV lose the formatting
  the parsers rely on.)

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Script missing from Workspace > Scripts | Wrong folder path, or Resolve wasn't restarted after copying |
| `ModuleNotFoundError: No module named 'docx'` | Step 5 wasn't completed — run the installer script |
| Panel opens tiny | Drag it larger once; if it happens every launch, report it |
| A button click does nothing / errors | Workspace > Console shows the Python traceback — copy it and send to Claude |
| Terminal prompt stuck showing `>` | You pasted something with backticks; press Ctrl+C |
| Downloaded file won't open on double-click | Don't open it — just move it into the Scripts folder; edit only with a code editor, never rich-text TextEdit |
