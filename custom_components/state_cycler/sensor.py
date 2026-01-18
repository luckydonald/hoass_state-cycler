"""Sensor platform for State Cycler."""

from __future__ import annotations

import logging

from homeassistant.components.sensor import SensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity import DeviceInfo
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, LOG_NAME

_LOGGER = logging.getLogger(LOG_NAME)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up State Cycler sensors."""
    # Example: Create a basic sensor
    sensors = [
        StateCyclerSensor(entry, "example"),
    ]

    async_add_entities(sensors)


class StateCyclerSensor(SensorEntity):
    """Representation of a State Cycler Sensor."""

    def __init__(self, entry: ConfigEntry, sensor_type: str) -> None:
        """Initialize the sensor."""
        self._entry = entry
        self._sensor_type = sensor_type
        self._attr_name = f"State Cycler {sensor_type.title()}"
        self._attr_unique_id = f"{entry.entry_id}_{sensor_type}"
        self._attr_native_value = None

    @property
    def device_info(self) -> DeviceInfo:
        """Return device info."""
        return DeviceInfo(
            identifiers={(DOMAIN, self._entry.entry_id)},
            name="State Cycler",
            manufacturer="Custom",
            model="State Cycler",
        )

    async def async_update(self) -> None:
        """Update the sensor."""
        # Add your update logic here
        # For example:
        # self._attr_native_value = await some_function()
        pass
