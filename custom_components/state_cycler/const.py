"""Constants for this plugin."""

import json
from typing import Final
from pathlib import Path

from homeassistant.loader import Manifest


DIR = Path(__file__).parent
MANIFEST_FILE = DIR / "manifest.json"

with open(MANIFEST_FILE) as f:
  MANIFEST_DATA: Manifest = json.load(f)
# end if


DOMAIN: Final[str] = MANIFEST_DATA['domain']
LOG_NAME: Final[str] = f"custom-components.{DOMAIN}"
