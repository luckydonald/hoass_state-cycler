"""Select platform adapter for State Cycler.

This module creates a SelectEntity per config entry that forwards user selection
requests to the authoritative core (stored on hass.data[DOMAIN][entry_id]['core']).

It exposes friendly names in the dropdown while mapping selections back to the
core's machine ids/indexes.
"""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.components.select import SelectEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect

from .const import DOMAIN, LOG_NAME, SIGNAL_UPDATE, ATTR_STATES, ATTR_INDEX, ATTR_INCLUDE_OFF_STATE

_LOGGER = logging.getLogger(LOG_NAME)


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, async_add_entities) -> None:
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
        self._attr_name = f"{self._name} (Selector)"
        self._unique_id = f"{entry.entry_id}_select"
        # display options shown in the UI (friendly names)
        self._options: list[str] = []
        # mapping from display option -> index into core states (int) or special 'off'
        self._option_to_index: dict[str, int | str] = {}
        self._current_option: str | None = None
        self._suppress_update = False

        # If core exists, register adapter (no HA writes here)
        core = hass.data.get(DOMAIN, {}).get(entry.entry_id, {}).get("core")
        if core:
            core.register_adapter("select", self)
        # Mark adapter initialized; HA writes will happen in async_added_to_hass
        self._initialized = True

    async def async_added_to_hass(self) -> None:
        """When entity is added to hass, connect dispatcher and sync state."""
        await super().async_added_to_hass()
        try:
            async_dispatcher_connect(self.hass, SIGNAL_UPDATE, self._async_update_from_dispatcher)
        except Exception:
            pass

        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            core.register_adapter("select", self)
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)
            # Now write initial HA state
            self.async_write_ha_state()

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

        Map the displayed friendly option back to the core index (or off) and
        forward the request to the core. The core will perform the action and
        notify adapters back. Adapters must not directly write their own state
        to avoid feedback loops.
        """
        core = self.hass.data[DOMAIN].get(self._entry.entry_id, {}).get("core")
        if not core:
            _LOGGER.warning("State Cycler core not ready for select action")
            return

        # Resolve option -> index or 'off'
        if option not in self._option_to_index:
            _LOGGER.error("Selected option not recognized: %s", option)
            return

        mapped = self._option_to_index[option]
        if mapped == "off":
            await core.async_handle_adapter_action("off")
            return

        # mapped is an integer index into core states
        try:
            index = int(mapped)
        except (TypeError, ValueError):
            _LOGGER.error("Invalid mapping for option %s -> %r", option, mapped)
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
        """Update adapter internal values based on core snapshot and write state.

        Builds a user-friendly options list and a stable mapping from option -> index.
        Handles duplicates by disambiguating with the entity_id when needed.
        """
        states = snapshot.get(ATTR_STATES, [])
        include_off = snapshot.get(ATTR_INCLUDE_OFF_STATE, False)

        # Build list of friendly names for each state
        friendly_names: list[str] = []
        for ent in states:
            state_obj = self.hass.states.get(ent)
            if state_obj:
                friendly = state_obj.attributes.get("friendly_name", ent)
            else:
                friendly = ent
            friendly_names.append(friendly)

        # Disambiguate duplicates by appending the entity_id where necessary
        counts: dict[str, int] = {}
        for name in friendly_names:
            counts[name] = counts.get(name, 0) + 1

        display_names: list[str] = []
        for ent, name in zip(states, friendly_names):
            if counts.get(name, 0) > 1:
                display = f"{name} — {ent}"
            else:
                display = name
            display_names.append(display)

        options: list[str]
        option_to_index: dict[str, int | str] = {}

        if include_off:
            options = ["Off"] + display_names
            option_to_index["Off"] = "off"
            offset = 1
        else:
            options = display_names
            offset = 0

        # Map each displayed option to its index in the core states
        for i, _ in enumerate(display_names):
            opt = options[offset + i]
            option_to_index[opt] = i

        # Update internal structures
        self._options = options
        self._option_to_index = option_to_index

        # Compute current option
        idx = snapshot.get(ATTR_INDEX, -1)
        if include_off and idx == -1:
            curr = "Off"
        elif idx == -1:
            curr = None
        else:
            curr = self._options[(idx + offset)]

        # Update internal state; HA write happens in async_added_to_hass or when platform present
        self._suppress_update = True
        self._current_option = curr
        self._suppress_update = False
