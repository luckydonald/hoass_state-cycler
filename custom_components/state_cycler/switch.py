"""Switch adapter for State Cycler."""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity import DeviceInfo

from .const import DOMAIN, LOG_NAME, SIGNAL_UPDATE, ATTR_INDEX

_LOGGER = logging.getLogger(LOG_NAME)


async def async_setup_entry(
    hass: HomeAssistant, entry: ConfigEntry, async_add_entities
) -> None:
    """Set up the switch adapter for a State Cycler config entry."""
    adapter = StateCyclerSwitch(hass, entry)
    async_add_entities([adapter])


class StateCyclerSwitch(SwitchEntity):
    """Switch adapter that mirrors the core cycler on/off state."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self._entry = entry
        self._name = entry.data.get("name", "State Cycler")
        self._attr_name = f"{self._name} (Power)"
        self._unique_id = f"{entry.entry_id}_switch"
        self._is_on = False

        # Listen for config updates / core notifications
        try:
            if isinstance(getattr(hass, "data", None), dict):
                async_dispatcher_connect(hass, SIGNAL_UPDATE, self._async_update_from_dispatcher)
        except Exception:
            pass

        # If core exists, register adapter and sync
        core = hass.data.get(entry.entry_id, {}).get("core")
        if core:
            core.register_adapter("switch", self)
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    @property
    def name(self) -> str:
        return f"{self._name} (Power)"

    @property
    def unique_id(self) -> str:
        return self._unique_id

    @property
    def is_on(self) -> bool:
        return self._is_on

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, self._entry.entry_id)},
            name=self._name,
            manufacturer="Custom",
            model="State Cycler (Switch Adapter)",
        )

    async def async_turn_on(self, **kwargs: Any) -> None:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if not core:
            _LOGGER.warning("State Cycler core not ready for switch on")
            return
        await core.async_handle_adapter_action("on")

    async def async_turn_off(self, **kwargs: Any) -> None:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if not core:
            _LOGGER.warning("State Cycler core not ready for switch off")
            return
        await core.async_handle_adapter_action("off")

    async def async_update(self) -> None:
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    def _async_update_from_dispatcher(self, updated_entry_id: str) -> None:
        if updated_entry_id != self._entry.entry_id:
            return
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            snap = core.get_state_snapshot()
            self._async_update_from_core(snap)

    def _async_update_from_core(self, snapshot: dict[str, Any]) -> None:
        idx = snapshot.get(ATTR_INDEX, -1)
        is_on = idx != -1
        self._is_on = is_on
        if getattr(self, "platform", None) is not None:
            self.async_write_ha_state()
