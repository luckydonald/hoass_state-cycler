"""Select platform adapter for State Cycler.

This module creates a SelectEntity per config entry that forwards user selection
requests to the authoritative core (stored on hass.data[DOMAIN][entry_id]['core']).
"""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.components.select import SelectEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect

from .const import (
    DOMAIN,
    LOG_NAME,
    SIGNAL_UPDATE,
    ATTR_STATES,
    ATTR_INDEX,
    ATTR_INCLUDE_OFF_STATE,
)

_LOGGER = logging.getLogger(LOG_NAME)


async def async_setup_entry(
    hass: HomeAssistant, entry: ConfigEntry, async_add_entities
) -> None:
    """Set up select adapter for a State Cycler config entry."""
    # Create and add the adapter entity
    adapter = StateCyclerSelect(hass, entry)
    async_add_entities([adapter])


class StateCyclerSelect(SelectEntity):
    """Select adapter for a State Cycler instance."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self._entry = entry
        self._name = entry.data.get("name", "State Cycler")
        self._unique_id = f"{entry.entry_id}_select"
        self._options: list[str] = []
        self._current_option: str | None = None
        self._suppress_update = False

        # Subscribe to core updates when available
        async_dispatcher_connect(
            hass, SIGNAL_UPDATE, self._async_update_from_dispatcher
        )

        # If core exists, request initial sync
        core = hass.data[DOMAIN].get(entry.entry_id, {}).get("core")
        if core:
            core.register_adapter("select", self)
            self._async_update_from_core(core.get_state_snapshot())

    @property
    def name(self) -> str:
        return f"{self._name} (Selector)"

    @property
    def unique_id(self) -> str:
        return self._unique_id

    @property
    def options(self) -> list[str]:
        return self._options

    @property
    def current_option(self) -> str | None:
        return self._current_option

    async def async_select_option(self, option: str) -> None:
        """Handle user selecting an option in the UI.

        Forward the request to the core. The core will perform the action and
        notify adapters back. Adapters must not directly write their own state
        to avoid feedback loops.
        """
        core = self.hass.data[DOMAIN].get(self._entry.entry_id, {}).get("core")
        if not core:
            _LOGGER.warning("State Cycler core not ready for select action")
            return

        try:
            index = self._options.index(option)
        except ValueError:
            _LOGGER.error("Selected option not in options: %s", option)
            return

        await core.async_handle_adapter_action("to", index=index)

    async def async_update(self) -> None:
        """Called by HA to update state - ensure we sync with core if present."""
        core = self.hass.data[DOMAIN].get(self._entry.entry_id, {}).get("core")
        if core:
            snapshot = core.get_state_snapshot()
            self._async_update_from_core(snapshot)

    @callback
    def _async_update_from_dispatcher(self, updated_entry_id: str) -> None:
        """Handle SIGNAL_UPDATE for config changes; request sync from core."""
        if updated_entry_id != self._entry.entry_id:
            return
        core = self.hass.data[DOMAIN].get(self._entry.entry_id, {}).get("core")
        if core:
            snapshot = core.get_state_snapshot()
            self._async_update_from_core(snapshot)

    @callback
    def _async_update_from_core(self, snapshot: dict[str, Any]) -> None:
        """Update adapter internal values based on core snapshot and write state."""
        # snapshot expected to include: states (list[str]), index (int), include_off_state (bool)
        states = snapshot.get(ATTR_STATES, [])
        include_off = snapshot.get(ATTR_INCLUDE_OFF_STATE, False)

        options: list[str]
        if include_off:
            options = ["Off"] + states
        else:
            options = states[:]

        self._options = options

        idx = snapshot.get(ATTR_INDEX, -1)
        if include_off:
            curr = "Off" if idx == -1 else self._options[idx + 1]
        else:
            curr = None if idx == -1 else self._options[idx]

        self._suppress_update = True
        self._current_option = curr
        self.async_write_ha_state()
        self._suppress_update = False
