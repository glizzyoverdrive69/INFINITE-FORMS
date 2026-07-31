#!/usr/bin/env python3
"""
Install python-docx for Infinite Forms -- run me from Resolve. (v2)

Put this file in:
  ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
Then: Workspace > Scripts > Utility > install_python_docx
Watch Workspace > Console for the result.
"""

import importlib
import os
import subprocess
import sys

print("=" * 60)

python_bin = os.path.join(sys.prefix, "bin", "python3")
print(f"Using Python: {python_bin}")

if not os.path.isfile(python_bin):
    print("Could not find the python3 binary at the path above.")
    print(f"sys.prefix is: {sys.prefix}")
    print("Send this output to Claude.")
else:
    # Force a UTF-8 environment for the child process, and read its
    # output as raw bytes -- Resolve's embedded env has no locale set,
    # which is what broke v1 of this script.
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"
    env.setdefault("LC_ALL", "en_US.UTF-8")
    env.setdefault("LANG", "en_US.UTF-8")

    try:
        result = subprocess.run(
            [python_bin, "-m", "pip", "install", "--user", "python-docx"],
            capture_output=True, timeout=600, env=env,
        )
        print(result.stdout.decode("utf-8", errors="replace"))
        print(result.stderr.decode("utf-8", errors="replace"))
        print(f"(pip exit code: {result.returncode} -- 0 means success)")
    except Exception as exc:
        print(f"Install failed to launch: {exc!r}")

    # --- Verify ---------------------------------------------------------
    importlib.invalidate_caches()
    try:
        import docx  # noqa: F401
        print("SUCCESS: python-docx is installed and visible to Resolve.")
        print("The Mid/Short Form Assembly button is ready to use.")
    except ImportError:
        # Common cause: the --user site-packages folder isn't on
        # Resolve's import path. Find it and test that theory.
        version_tag = f"{sys.version_info.major}.{sys.version_info.minor}"
        user_site = os.path.expanduser(
            f"~/Library/Python/{version_tag}/lib/python/site-packages"
        )
        print(f"Resolve can't import docx yet. Checking {user_site} ...")
        installed_there = os.path.isdir(os.path.join(user_site, "docx"))
        print(f"docx present in that folder: {installed_there}")
        print(f"that folder on Resolve's path: {user_site in sys.path}")

        if installed_there and user_site not in sys.path:
            sys.path.insert(0, user_site)
            importlib.invalidate_caches()
            try:
                import docx  # noqa: F401
                print("CONFIRMED: the library is installed; Resolve just")
                print("doesn't look in the user site-packages folder.")
                print("Tell Claude exactly this -- the plugin needs a")
                print("two-line path fix, no reinstalling required.")
            except ImportError:
                print("Still failing even with the path added.")
                print("Copy ALL output above and send it to Claude.")
        else:
            print("Copy ALL output above and send it to Claude.")

print("=" * 60)
