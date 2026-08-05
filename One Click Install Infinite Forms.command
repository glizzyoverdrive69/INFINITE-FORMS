#!/bin/bash
#
# Infinite Forms -- double-click installer
# ========================================
# Does every step of INSTALL.md that can be automated:
#   1. checks every dependency the plugin needs, and says which of them
#      are hard requirements vs which only cost you individual features
#   2. finds DaVinci Resolve and the plugin source
#   3. validates the plugin file before touching anything
#   4. copies it (plus the docx helper) into Resolve's Scripts/Utility
#   5. installs python-docx into the Python(s) Resolve is likely to use
#
# The two steps that CANNOT be automated are printed at the end:
# Resolve's "External scripting using -> Local" preference (it lives in an
# opaque binary config that we will not hand-edit), and the restart.
#
# Runs entirely in the user's home folder -- no sudo, nothing system-wide.
#

set -uo pipefail

REPO="glizzyoverdrive69/INFINITE-FORMS"
BRANCH="main"
PLUGIN="infinite_forms_plugin.py"
HELPER="install_python_docx.py"
EOF_SENTINEL="# INFINITE-FORMS-EOF"
MIN_BYTES=50000          # same floor the plugin's own auto-updater uses

# Blackmagic's own scripting README names Python 3.6 as the floor and sets
# no ceiling.
MIN_PYTHON="3.6"
# Assembly copies the approved package grades across with CopyGrades(),
# which arrived in Resolve 18.5. Everything else works below that, so this
# is a warning rather than a blocker.
MIN_RESOLVE_FOR_GRADES="18.5"

DEST="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Output helpers --------------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 \
   && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    BOLD=$(tput bold); RESET=$(tput sgr0)
    GOLD=$(tput setaf 3); RED=$(tput setaf 1); GREEN=$(tput setaf 2)
else
    BOLD=""; RESET=""; GOLD=""; RED=""; GREEN=""
fi

FAILED=0
step() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"; }
ok()   { printf '   %s.%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '   %s!%s %s\n' "$GOLD" "$RESET" "$1"; }
bad()  { printf '   %sx%s %s\n' "$RED" "$RESET" "$1"; FAILED=1; }
info() { printf '     %s\n' "$1"; }

finish() {
    printf '\n%s\n' "------------------------------------------------------------"
    if [ "$FAILED" -eq 0 ]; then
        printf '%s%sInstalled.%s\n\n' "$BOLD" "$GREEN" "$RESET"
        printf 'Two things left, both inside Resolve:\n\n'
        printf '  1. Preferences > General > "External scripting using" -> Local\n'
        printf '     (Resolve stores this in a binary config, so an installer\n'
        printf '      cannot set it safely. One click, once per machine.)\n\n'
        printf '  2. Quit and reopen Resolve -- it only scans the Scripts\n'
        printf '     folder at launch.\n\n'
        printf 'Then: %sWorkspace > Scripts > Utility > infinite_forms_plugin%s\n' \
               "$BOLD" "$RESET"
        printf '\nSmoke test that costs nothing: click Bin Finder.\n'
        printf '\nOne last thing this installer cannot check: some features\n'
        printf 'depend on assets inside each Resolve PROJECT, not on this\n'
        printf 'computer -- the TM_LOWER_LEFT_THIRD_TEMPLATE title, the two\n'
        printf 'CRM colour groups, and a RAW-FILES bin. Set them up once in\n'
        printf 'your house template and every job inherits them. See the\n'
        printf '"Per-project assets" section of INSTALL.md.\n'
    else
        printf '%s%sInstall did not complete.%s\n\n' "$BOLD" "$RED" "$RESET"
        printf 'Scroll up for the line(s) marked x, copy this whole window,\n'
        printf 'and send it on. Nothing was left half-written -- the plugin\n'
        printf 'file is only replaced after it passes validation.\n'
    fi
    printf '\n'
    # .command windows linger anyway, but an explicit pause means the user
    # sees the result instead of a wall of scrollback.
    read -r -n 1 -p "Press any key to close this window. " _ 2>/dev/null || true
    printf '\n'
    exit "$FAILED"
}

# --- Banner ----------------------------------------------------------------
clear 2>/dev/null || true
printf '%s%s\n' "$GOLD" "============================================================"
printf '  I N F I N I T E   F O R M S\n'
printf '  installer\n'
printf '============================================================%s\n' "$RESET"

# --- 1. Platform -----------------------------------------------------------
step "Checking this machine"
if [ "$(uname -s)" != "Darwin" ]; then
    bad "This installer is macOS-only (found $(uname -s))."
    finish
fi
ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '?')"

# --- 2. Dependencies -------------------------------------------------------
# Two tiers, and the output says which is which:
#   HARD  -- the panel cannot open at all without it, so we stop
#   SOFT  -- costs you specific features; install continues
step "Checking dependencies"

# Compare dotted versions without bc/sort -V (neither is dependable here).
version_ge() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        split(a, x, "."); split(b, y, ".")
        for (i = 1; i <= 4; i++) {
            av = x[i] + 0; bv = y[i] + 0
            if (av > bv) { exit 0 }
            if (av < bv) { exit 1 }
        }
        exit 0
    }'
}

# --- Resolve itself (SOFT: files still land in the right place) -----------
RESOLVE_APP=""
for candidate in \
    "/Applications/DaVinci Resolve/DaVinci Resolve.app" \
    "/Applications/DaVinci Resolve.app"; do
    if [ -d "$candidate" ]; then RESOLVE_APP="$candidate"; break; fi
done

RESOLVE_LIB=""
if [ -n "$RESOLVE_APP" ]; then
    RESOLVE_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
                  "$RESOLVE_APP/Contents/Info.plist" 2>/dev/null)
    ok "DaVinci Resolve ${RESOLVE_VER:-(version unknown)}"
    info "$RESOLVE_APP"

    if [ -n "$RESOLVE_VER" ] \
       && ! version_ge "$RESOLVE_VER" "$MIN_RESOLVE_FOR_GRADES"; then
        warn "Resolve $RESOLVE_VER is older than $MIN_RESOLVE_FOR_GRADES."
        info "Everything works except copying the approved package grades"
        info "in Mid/Short Form Assembly (needs CopyGrades). Those clips"
        info "come through with the raw bin look instead."
    fi

    # Studio vs free cannot be read reliably from the bundle -- both are
    # named "DaVinci Resolve". Report what we can see and move on; the
    # plugin fails loudly at launch on the free edition, because UIManager
    # simply is not there.
    if grep -qi "studio" "$RESOLVE_APP/Contents/Info.plist" 2>/dev/null; then
        ok "Studio edition"
    else
        warn "Could not confirm this is Resolve STUDIO from the app bundle."
        info "The free edition has no UIManager and the panel will not open."
        info "If the splash screen says \"Studio\", you are fine."
    fi

    # The scripting library the plugin's bootstrap falls back to.
    if [ -f "$RESOLVE_APP/Contents/Libraries/Fusion/fusionscript.so" ]; then
        RESOLVE_LIB="$RESOLVE_APP/Contents/Libraries/Fusion/fusionscript.so"
        ok "fusionscript.so present"
    else
        warn "fusionscript.so is missing from the Resolve bundle."
        info "The plugin has three other ways to connect, so this is not"
        info "fatal -- but a reinstall of Resolve would be worth doing."
    fi
else
    warn "DaVinci Resolve is not in /Applications."
    info "Installing anyway -- the files go to the right place and will be"
    info "picked up whenever Resolve is installed."
fi

# --- DaVinciResolveScript.py (SOFT: it is one of four fallbacks) ----------
DVR_FOUND=""
for modules in \
    "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules" \
    "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules"; do
    if [ -f "$modules/DaVinciResolveScript.py" ]; then DVR_FOUND="$modules"; break; fi
done
if [ -n "$DVR_FOUND" ]; then
    ok "DaVinciResolveScript.py present"
else
    warn "DaVinciResolveScript.py not found in the standard Modules folders."
    info "Only matters if the direct fusionscript.so route also fails."
fi

# --- Python (HARD) --------------------------------------------------------
# Resolve on macOS uses an EXTERNAL python.org framework Python, and the
# --user site-packages folder it imports from is version-specific
# (~/Library/Python/3.x/...). We cannot ask Resolve which one it picked
# from out here, so python-docx goes into every one we find -- cheap, and
# it guarantees a hit.
PYTHONS=()
SEEN_SITES=()
add_python() {
    local candidate="$1" site
    [ -x "$candidate" ] || return 0
    # Dedupe on the --user site-packages folder, NOT on the binary path:
    # /usr/local/bin/python3 and the framework python3 are usually the same
    # install reached two ways, and they share that folder. Keying on it
    # means one pip run per place docx can actually land.
    site="$("$candidate" -c 'import site; print(site.getusersitepackages())' 2>/dev/null)" || return 0
    [ -n "$site" ] || return 0
    for existing in ${SEEN_SITES+"${SEEN_SITES[@]}"}; do
        [ "$existing" = "$site" ] && return 0
    done
    SEEN_SITES+=("$site")
    PYTHONS+=("$candidate")
}

for framework in /Library/Frameworks/Python.framework/Versions/*/bin/python3; do
    case "$framework" in *"/Versions/Current/"*) continue ;; esac
    add_python "$framework"
done
add_python "$(command -v python3 2>/dev/null || true)"
add_python "/usr/local/bin/python3"
add_python "/opt/homebrew/bin/python3"
add_python "/usr/bin/python3"

if [ "${#PYTHONS[@]}" -eq 0 ]; then
    bad "No working Python 3 found -- this is a hard requirement."
    info "The plugin IS a Python script; without one nothing can run."
    info "Install the Python 3 macOS installer from python.org"
    info "(INSTALL.md step 2), then double-click this installer again."
    finish
fi

# Rather than trusting version numbers, prove each Python can actually
# drive Resolve: load the same fusionscript.so the plugin's own bootstrap
# falls back to and check the entry point is there. That is the real
# dependency -- a Python that cannot load it cannot run the panel.
cat > "$TMP/probe.py" <<'PROBE'
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.ExtensionFileLoader("fusionscript", sys.argv[1])
spec = importlib.util.spec_from_loader("fusionscript", loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)
sys.exit(0 if hasattr(mod, "scriptapp") else 1)
PROBE

GOOD_PYTHONS=()
PY_DRIVES_RESOLVE=0
for py in "${PYTHONS[@]}"; do
    pv=$("$py" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)
    if [ -z "$pv" ] || ! version_ge "$pv" "$MIN_PYTHON"; then
        warn "Python ${pv:-?} -- below the $MIN_PYTHON floor, skipping"
        info "$py"
        continue
    fi
    GOOD_PYTHONS+=("$py")
    if [ -n "$RESOLVE_LIB" ]; then
        if "$py" "$TMP/probe.py" "$RESOLVE_LIB" >/dev/null 2>&1; then
            ok "Python $pv -- can load Resolve's scripting library"
            PY_DRIVES_RESOLVE=1
        else
            warn "Python $pv -- cannot load Resolve's scripting library"
            info "$py"
            info "Resolve will not be using this one. Harmless as long as"
            info "another Python here passes."
        fi
    else
        ok "Python $pv"
        info "$py"
    fi
done

if [ "${#GOOD_PYTHONS[@]}" -eq 0 ]; then
    bad "Every Python found is older than $MIN_PYTHON."
    info "Blackmagic's own scripting docs name $MIN_PYTHON as the minimum."
    info "Install a current Python 3 from python.org and run this again."
    finish
fi
PYTHONS=("${GOOD_PYTHONS[@]}")

case "$PY_DRIVES_RESOLVE:$RESOLVE_LIB" in
    0:"") : ;;   # no Resolve to test against -- already reported above
    0:*)
        warn "No Python here could load Resolve's scripting library."
        info "The panel will probably fail to connect. The usual cause is a"
        info "Homebrew-only Python -- install the python.org one instead."
        ;;
esac

# --- HTTPS certificates (SOFT, but it silently breaks update checks) ------
# A python.org Python ships WITHOUT a CA bundle until its own
# "Install Certificates.command" is run. Until then every HTTPS request
# from that Python fails certificate verification -- while curl, Safari and
# everything else work fine, because they use the system store. The panel's
# Check for Update button then reports "offline" on a machine that is
# plainly online, which is impossible to diagnose from the outside.
for py in "${PYTHONS[@]}"; do
    cafile=$("$py" -c 'import ssl; print(ssl.get_default_verify_paths().openssl_cafile or "")' 2>/dev/null)
    pv=$("$py" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
    if [ -z "$cafile" ] || [ -f "$cafile" ]; then
        continue        # either not applicable, or the bundle is there
    fi

    certfix="/Applications/Python $pv/Install Certificates.command"
    if [ -x "$certfix" ] && [ -w "$(dirname "$cafile")" ]; then
        warn "Python $pv has no HTTPS certificates -- running python.org's"
        info "own Install Certificates.command to fix it (no password"
        info "needed; it writes only into that Python's own folder)."
        if "$certfix" >"$TMP/certs.log" 2>&1 && [ -f "$cafile" ]; then
            ok "Python $pv -- certificates installed"
        else
            warn "Python $pv -- the certificate fix did not complete"
            info "Update checks from the panel will report being offline."
            info "Try double-clicking it yourself:"
            info "$certfix"
            tail -3 "$TMP/certs.log" 2>/dev/null | sed 's/^/     /'
        fi
    else
        warn "Python $pv has no HTTPS certificates installed."
        info "The panel's Check for Update will wrongly report that this"
        info "machine is offline. Fix: open the Applications folder, open"
        info "the \"Python $pv\" folder, and double-click"
        info "\"Install Certificates.command\"."
    fi
done

# --- curl (SOFT: only needed for the download fallback) -------------------
if command -v curl >/dev/null 2>&1; then
    ok "curl present"
else
    warn "curl not found -- cannot download anything."
    info "Only matters if the plugin file is not sitting next to this"
    info "installer."
fi

# --- 3. Locate the plugin source ------------------------------------------
step "Locating the plugin"
SRC=""
if [ -f "$SCRIPT_DIR/$PLUGIN" ]; then
    SRC="$SCRIPT_DIR/$PLUGIN"
    ok "Using the copy sitting next to this installer"
else
    info "No $PLUGIN next to this installer -- fetching from GitHub..."
    if curl -fsSL --max-time 30 \
            -o "$TMP/$PLUGIN" \
            "https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN" 2>/dev/null; then
        SRC="$TMP/$PLUGIN"
        ok "Downloaded from $REPO ($BRANCH)"
    else
        bad "Could not download the plugin."
        info "Either you are offline, or the repo is private."
        info "Fix: put this installer in the same folder as $PLUGIN"
        info "and double-click it again."
        finish
    fi
fi

# --- 4. Validate before touching anything ---------------------------------
# The same three gates the plugin's auto-updater uses, for the same reason:
# a truncated file must never replace a working install.
step "Validating the plugin file"
BYTES=$(wc -c < "$SRC" | tr -d ' ')
if [ "$BYTES" -lt "$MIN_BYTES" ]; then
    bad "File is suspiciously small ($BYTES bytes, expected > $MIN_BYTES)."
    info "That means a truncated download or the wrong file. Nothing copied."
    finish
fi
ok "Size sane ($BYTES bytes)"

# A Python is guaranteed by the dependency stage above, so this gate
# always runs.
if "${PYTHONS[0]}" -c "import sys; compile(open(sys.argv[1]).read(), 'p', 'exec')" \
        "$SRC" 2>"$TMP/compile.err"; then
    ok "Compiles cleanly"
else
    bad "The plugin file does not compile -- it is damaged or truncated."
    sed 's/^/     /' "$TMP/compile.err" | tail -5
    finish
fi

if ! tail -5 "$SRC" | grep -qF "$EOF_SENTINEL"; then
    bad "End-of-file marker missing -- the file was cut short. Nothing copied."
    finish
fi
ok "End-of-file marker present"

BUILD=$(grep -m1 '^BUILD_TAG *= *"' "$SRC" | sed 's/.*"\(.*\)".*/\1/')
[ -n "$BUILD" ] && ok "Build $BUILD"

# --- 5. Install ------------------------------------------------------------
step "Installing into Resolve's Scripts folder"
if ! mkdir -p "$DEST" 2>/dev/null; then
    bad "Could not create $DEST"
    finish
fi
ok "Folder ready"
info "$DEST"

if [ -f "$DEST/$PLUGIN" ]; then
    if cp "$DEST/$PLUGIN" "$DEST/$PLUGIN.bak" 2>/dev/null; then
        PREV=$(grep -m1 '^BUILD_TAG *= *"' "$DEST/$PLUGIN.bak" \
               | sed 's/.*"\(.*\)".*/\1/')
        ok "Previous version backed up as $PLUGIN.bak${PREV:+ (build $PREV)}"
    else
        warn "Could not back up the existing install -- continuing anyway."
    fi
fi

install_file() {
    local src="$1" name="$2"
    if cp "$src" "$DEST/$name" 2>/dev/null; then
        chmod 644 "$DEST/$name" 2>/dev/null || true
        # Files that arrived inside a downloaded .zip carry the quarantine
        # flag; Resolve refuses to run those.
        xattr -d com.apple.quarantine "$DEST/$name" 2>/dev/null || true
        ok "$name"
        return 0
    fi
    bad "Could not copy $name into $DEST"
    return 1
}

install_file "$SRC" "$PLUGIN" || finish

# The in-Resolve docx installer, from wherever it lives in this layout.
HELPER_SRC=""
for candidate in "$SCRIPT_DIR/scripts/$HELPER" "$SCRIPT_DIR/$HELPER"; do
    [ -f "$candidate" ] && HELPER_SRC="$candidate" && break
done
if [ -z "$HELPER_SRC" ]; then
    if curl -fsSL --max-time 30 -o "$TMP/$HELPER" \
            "https://raw.githubusercontent.com/$REPO/$BRANCH/scripts/$HELPER" 2>/dev/null; then
        HELPER_SRC="$TMP/$HELPER"
    fi
fi
if [ -n "$HELPER_SRC" ]; then
    install_file "$HELPER_SRC" "$HELPER" || true
else
    warn "Could not find $HELPER -- skipping it."
    info "Only needed as a fallback if the docx install below fails."
fi

# Confirm what actually landed on disk, rather than trusting the copy.
if "${PYTHONS[0]}" -c "import sys; compile(open(sys.argv[1]).read(), 'p', 'exec')" \
        "$DEST/$PLUGIN" 2>/dev/null; then
    ok "Installed file verified on disk"
else
    bad "The installed file does not compile. Restoring the backup."
    [ -f "$DEST/$PLUGIN.bak" ] && mv "$DEST/$PLUGIN.bak" "$DEST/$PLUGIN"
    finish
fi

# --- 6. python-docx --------------------------------------------------------
# Needed by Mid/Short Form Assembly and Sort by Shoot Notes. Everything
# else in the panel works without it, so a failure here is a warning.
step "Installing python-docx"
DOCX_OK=0
for py in "${PYTHONS[@]}"; do
    version=$("$py" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
    label="Python ${version:-?}"
    if "$py" -c "import docx" >/dev/null 2>&1; then
        ok "$label -- already present"
        DOCX_OK=1
        continue
    fi
    # pip itself is a dependency, and Homebrew/OS pythons sometimes ship
    # without it. Say so plainly instead of dumping a module error.
    if ! "$py" -m pip --version >/dev/null 2>&1; then
        warn "$label -- pip is not available in this Python"
        info "$py"
        continue
    fi
    if PYTHONIOENCODING=utf-8 "$py" -m pip install --user --quiet python-docx \
            >"$TMP/pip.log" 2>&1 && "$py" -c "import docx" >/dev/null 2>&1; then
        ok "$label -- installed"
        DOCX_OK=1
    else
        warn "$label -- could not install"
        info "$py"
        if grep -q "externally-managed-environment" "$TMP/pip.log" 2>/dev/null; then
            info "This Python is managed by Homebrew/the OS and blocks"
            info "--user installs. Harmless if another Python above"
            info "succeeded -- Resolve uses the python.org one."
        elif grep -qi "lxml" "$TMP/pip.log" 2>/dev/null; then
            info "The failure is in lxml, which python-docx depends on."
            info "Usually means no prebuilt wheel exists yet for this very"
            info "new Python, so pip tried to compile it. A slightly older"
            info "python.org version will install cleanly."
        else
            tail -3 "$TMP/pip.log" 2>/dev/null | sed 's/^/     /'
        fi
    fi
done
if [ "$DOCX_OK" -eq 0 ]; then
    warn "python-docx is not installed in any Python found here."
    info "The panel still opens and five of the seven tools work."
    info "For the other two, run this from inside Resolve once:"
    info "Workspace > Scripts > Utility > install_python_docx"
    info "(it targets whichever Python Resolve actually loaded)"
fi

finish
