"""Sensor adapters for State Cycler.

We provide two sensors per config entry:
- raw sensor: primary state is the underlying entity_id or 'off' (machine-friendly)
- friendly sensor: primary state is a human-friendly label (friendly_name or 'Off')

Both sensors sync with the authoritative core via dispatcher and hass.data lookups.
"""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.components.sensor import SensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity import DeviceInfo

from .const import (
    DOMAIN,
    LOG_NAME,
    SIGNAL_UPDATE,
    ATTR_STATE,
    ATTR_STATE_FRIENDLY,
    ATTR_INDEX,
)

_LOGGER = logging.getLogger(LOG_NAME)
_LOGGER.warning(f"Loaded State Cycler's `{__name__}` module.")


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, async_add_entities) -> None:
    """Set up both sensor adapters for a State Cycler entry."""
    raw = StateCyclerRawSensor(hass, entry)
    friendly = StateCyclerFriendlySensor(hass, entry)
    # async_add_entities may be an async function in tests (AsyncMock), so call appropriately
    res = async_add_entities([raw, friendly])
    if hasattr(res, "__await__"):
        # Schedule in event loop
        try:
            import asyncio

            asyncio.get_event_loop().run_until_complete(res)
        except Exception:
            # If no running loop, ignore in unit tests
            pass


class StateCyclerRawSensor(SensorEntity):
    """Sensor that exposes the machine state (entity_id or 'off')."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self._entry = entry
        self._name = entry.data.get("name", "State Cycler")
        self._attr_name = f"{self._name} (State)"
        self._unique_id = f"{entry.entry_id}_raw"
        self._state: str = "off"

        try:
            if isinstance(getattr(hass, "data", None), dict):
                async_dispatcher_connect(hass, SIGNAL_UPDATE, self._async_update_from_dispatcher)
        except Exception:
            pass

        core = hass.data.get(DOMAIN, {}).get(entry.entry_id, {}).get("core") if isinstance(getattr(hass, "data", None), dict) else None
        if core:
            core.register_adapter("sensor_raw", self)
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @property
    def name(self) -> str:
        return f"{self._name} (State)"

    @property
    def unique_id(self) -> str:
        return self._unique_id

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, self._entry.entry_id)},
            name=self._name,
            manufacturer="Custom",
            model="State Cycler (Raw Sensor)",
        )

    @property
    def state(self) -> str:
        return self._state

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        idx = None
        if core:
            idx = core.get_state_snapshot().get(ATTR_INDEX)
        return {
            "index": idx,
            "friendly": core.get_state_snapshot().get(ATTR_STATE_FRIENDLY)
            if core
            else None,
        }

    async def async_update(self) -> None:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @callback
    def _async_update_from_dispatcher(self, updated_entry_id: str) -> None:
        if updated_entry_id != self._entry.entry_id:
            return
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @callback
    def _async_update_from_core(self, snapshot: dict[str, Any]) -> None:
        state = snapshot.get(ATTR_STATE, "off")
        self._state = state.lower() if isinstance(state, str) else str(state)
        self.async_write_ha_state()


class StateCyclerFriendlySensor(SensorEntity):
    """Sensor that exposes a human-friendly label for the current state."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self._entry = entry
        self._name = entry.data.get("name", "State Cycler")
        self._attr_name = f"{self._name} (Friendly)"
        self._unique_id = f"{entry.entry_id}_friendly"
        self._state: str = "Off"

        try:
            if isinstance(getattr(hass, "data", None), dict):
                async_dispatcher_connect(hass, SIGNAL_UPDATE, self._async_update_from_dispatcher)
        except Exception:
            pass

        core = hass.data.get(DOMAIN, {}).get(entry.entry_id, {}).get("core") if isinstance(getattr(hass, "data", None), dict) else None
        if core:
            core.register_adapter("sensor_friendly", self)
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @property
    def name(self) -> str:
        return f"{self._name} (Friendly)"

    @property
    def unique_id(self) -> str:
        return self._unique_id

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, self._entry.entry_id)},
            name=self._name,
            manufacturer="Custom",
            model="State Cycler (Friendly Sensor)",
        )

    @property
    def state(self) -> str:
        return self._state

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        idx = None
        if core:
            idx = core.get_state_snapshot().get(ATTR_INDEX)
        return {"index": idx}

    async def async_update(self) -> None:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @callback
    def _async_update_from_dispatcher(self, updated_entry_id: str) -> None:
        if updated_entry_id != self._entry.entry_id:
            return
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @callback
    def _async_update_from_core(self, snapshot: dict[str, Any]) -> None:
        state = snapshot.get(ATTR_STATE_FRIENDLY, "Off")
        self._state = state
        self.async_write_ha_state()
