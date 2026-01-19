"""Sensor platform for State Cycler."""

from __future__ import annotations

import logging

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, LOG_NAME

_LOGGER = logging.getLogger(LOG_NAME)
_LOGGER.warning(f"Loaded State Cycler's `{__name__}` module.")

# Forward platform setup to the main implementation
from . import state_cycler as _state_cycler  # noqa: E402


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up State Cycler sensors by forwarding to state_cycler.async_setup_entry."""
    _LOGGER.warning(f"Forwarding State Cycler sensor setup to state_cycler
 {entry=!r}")
    await _state_cycler.async_setup_entry(hass, entry, async_add_entities)
