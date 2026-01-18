"""Constants for the State Cycler integration."""
from typing import Final

DOMAIN: Final = "state_cycler"

# Events
EVENT_CYCLED: Final = f"{DOMAIN}.cycled"
EVENT_INITIALIZED: Final = f"{DOMAIN}.initialized"
EVENT_CYCLE_TIMEOUT: Final = f"{DOMAIN}.cycle_timeout"

# Attributes
ATTR_FRIENDLY_NAME: Final = "friendly_name"
ATTR_STATE: Final = "state"
ATTR_STATE_FRIENDLY: Final = "state_friendly"
ATTR_INDEX: Final = "index"
ATTR_TOGGLE_STATE: Final = "toggle_state"
ATTR_INCLUDE_OFF_STATE: Final = "include_off_state"
ATTR_LAST_STATE: Final = "last_state"
ATTR_LAST_INDEX: Final = "last_index"
ATTR_TIMER_INTERVAL: Final = "timer_interval"
ATTR_STATES: Final = "states"

# Services
SERVICE_NEXT: Final = "next"
SERVICE_PREV: Final = "prev"
SERVICE_TO: Final = "to"
SERVICE_OFF: Final = "off"
SERVICE_ON: Final = "on"
SERVICE_SWITCH: Final = "switch"
SERVICE_CYCLE: Final = "cycle"

# Config keys
CONF_STATES: Final = "states"
CONF_INCLUDE_OFF_STATE: Final = "include_off_state"
CONF_TIMER_INTERVAL: Final = "timer_interval"

# Defaults
DEFAULT_NAME: Final = "State Cycler"
DEFAULT_INCLUDE_OFF_STATE: Final = False
