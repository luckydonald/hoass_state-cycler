#!/usr/bin/env python3
"""Update README.md compatibility table from hacs.json.

This script looks for <!-- compat-table-start --> and <!-- compat-table-end --> markers
and replaces the content between them with a generated table based on `hacs.json`.

It expects `hacs.json` to contain at least the `homeassistant` field.
"""

import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
HACS = ROOT / "hacs.json"
README = ROOT / "README.md"

START_MARKER = "<!-- compat-table-start -->"
END_MARKER = "<!-- compat-table-end -->"


def read_hacs():
    if not HACS.exists():
        raise SystemExit(f"hacs.json not found at {HACS}")
    return json.loads(HACS.read_text())


def render_table(hass_version: str, release_tag: str) -> str:
    # Build a minimal table. The right column shows the release tag.
    lines = [
        START_MARKER,
        "Min. Homeassistant | Max. `plugin_template`",
        "-- | --",
        f"[{hass_version}](https://www.home-assistant.io/) | [{release_tag}](https://github.com/luckydonald/hoass_plugin_template/releases/tag/{release_tag})",
        END_MARKER,
    ]
    return "\n".join(lines)


def update_readme():
    if not README.exists():
        raise SystemExit("README.md not found")

    txt = README.read_text()

    if START_MARKER not in txt or END_MARKER not in txt:
        # Append markers and table at the end
        print("Markers not found, appending compatibility section to README.md")
        # Use hacs.json values
        hacs = read_hacs()
        hass = hacs.get("homeassistant", "unknown")
        # for first pass, use pyproject version as a placeholder tag
        pyproject = (ROOT / "pyproject.toml").read_text()
        m = re.search(r'(?m)^version\s*=\s*"([^"]+)"', pyproject)
        tag = m.group(1) if m else "0.0.0"
        table = "\n\n## 📚 Compatibility\n\n" + render_table(hass, tag) + "\n"
        README.write_text(txt + table)
        return True

    # Replace existing section
    pre, rest = txt.split(START_MARKER, 1)
    _, post = rest.split(END_MARKER, 1)

    hacs = read_hacs()
    hass = hacs.get("homeassistant", "unknown")
    pyproject = (ROOT / "pyproject.toml").read_text()
    m = re.search(r'(?m)^version\s*=\s*"([^"]+)"', pyproject)
    tag = m.group(1) if m else "0.0.0"

    new_section = render_table(hass, tag)

    new_txt = pre + new_section + post
    if new_txt == txt:
        print("No changes necessary in README.md")
        return False

    README.write_text(new_txt)
    print("Updated README.md compatibility table")
    return True


if __name__ == "__main__":
    changed = update_readme()
    sys.exit(0 if not changed else 0)
