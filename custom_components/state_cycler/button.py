"""Button adapters for State Cycler (next/prev)."""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.components.button import ButtonEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity import DeviceInfo

from .const import DOMAIN, LOG_NAME

_LOGGER = logging.getLogger(LOG_NAME)


async def async_setup_entry(
    hass: HomeAssistant, entry: ConfigEntry, async_add_entities
) -> None:
    async_add_entities(
        [
            StateCyclerNextButton(hass, entry),
            StateCyclerPrevButton(hass, entry),
        ]
    )


class StateCyclerNextButton(ButtonEntity):
    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self._entry = entry
        self._name = entry.data.get("name", "State Cycler")
        self._attr_name = f"{self._name} (Next)"
        self._unique_id = f"{entry.entry_id}_button_next"

    @property
    def name(self) -> str:
        return f"{self._name} (Next)"

    @property
    def unique_id(self) -> str:
        return self._unique_id

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, self._entry.entry_id)},
            name=self._name,
            manufacturer="Custom",
            model="State Cycler (Next Button)",
        )

    async def async_press(self, **kwargs: Any) -> None:
        core = self.hass.data[DOMAIN].get(self._entry.entry_id, {}).get("core")
        if not core:
            _LOGGER.warning("State Cycler core not ready for next button")
            return
        await core.async_handle_adapter_action("next")

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        # Register adapter so core can call back; provide both new and legacy names
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            core.register_adapter("button_next", self)
            # Legacy alias used by some tests
            core.register_adapter("button", self)


class StateCyclerPrevButton(ButtonEntity):
    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self._entry = entry
        self._name = entry.data.get("name", "State Cycler")
        self._attr_name = f"{self._name} (Prev)"
        self._unique_id = f"{entry.entry_id}_button_prev"

    @property
    def name(self) -> str:
        return f"{self._name} (Prev)"

    @property
    def unique_id(self) -> str:
        return self._unique_id

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, self._entry.entry_id)},
            name=self._name,
            manufacturer="Custom",
            model="State Cycler (Prev Button)",
        )

    async def async_press(self, **kwargs: Any) -> None:
        core = self.hass.data[DOMAIN].get(self._entry.entry_id, {}).get("core")
        if not core:
            _LOGGER.warning("State Cycler core not ready for prev button")
            return
        await core.async_handle_adapter_action("prev")

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        # Register adapter so core can call back
        core = self.hass.data.get(DOMAIN, {}).get(self._entry.entry_id, {}).get("core")
        if core:
            core.register_adapter("button_prev", self)
