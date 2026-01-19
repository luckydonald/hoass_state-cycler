"""State Cycler integration for Home Assistant."""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.entity_component import EntityComponent

from .const import DOMAIN, LOG_NAME, PLATFORMS, SIGNAL_UPDATE

_LOGGER = logging.getLogger(LOG_NAME)
_LOGGER.warning(f"Loaded State Cycler's `{__name__}` module.")

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)


async def async_setup(hass: HomeAssistant, config: dict[str, Any]) -> bool:
    """Set up the State Cycler component."""
    _LOGGER.warning(f"Setting up State Cycler (__init__.py)… {config=!r}")

    hass.data.setdefault(DOMAIN, {})

    # Create and store the EntityComponent for the custom domain so we can add core entities
    if "component" not in hass.data[DOMAIN]:
        component = EntityComponent(_LOGGER, DOMAIN, hass)
        hass.data[DOMAIN]["component"] = component

    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up State Cycler from a config entry."""
    _LOGGER.warning(f"Setting up State Cycler entry (__init__.py)… {entry=!r}")
    hass.data.setdefault(DOMAIN, {})
    hass.data[DOMAIN].setdefault(entry.entry_id, {})

    # Create the authoritative core entity via the EntityComponent
    from . import state_cycler as _state_cycler

    # Ensure component exists (tests may not have called async_setup)
    if "component" not in hass.data[DOMAIN]:
        hass.data[DOMAIN]["component"] = EntityComponent(_LOGGER, DOMAIN, hass)

    component: EntityComponent = hass.data[DOMAIN]["component"]
    core_entity = _state_cycler.StateCyclerEntity(hass, entry)

    # Register core entity and store reference for adapters
    await component.async_add_entities([core_entity])
    hass.data[DOMAIN][entry.entry_id]["core"] = core_entity

    # Forward setup to adapter platforms (select/switch/button/sensor)
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)

    entry.async_on_unload(entry.add_update_listener(async_update_options))

    return True


async def async_update_options(hass: HomeAssistant, entry: ConfigEntry) -> None:
    """Update options."""
    _LOGGER.warning(f"Update State Cycler entry options (__init__.py)… {entry=!r}")

    # Notify adapters that config changed
    async_dispatcher_send(hass, SIGNAL_UPDATE, entry.entry_id)

    await hass.config_entries.async_reload(entry.entry_id)


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload a config entry."""
    _LOGGER.warning(f"Unload State Cycler entry (__init__.py)… {entry=!r}")

    unload_ok = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)

    if unload_ok and entry.entry_id in hass.data[DOMAIN]:
        # Remove core entity reference
        hass.data[DOMAIN].pop(entry.entry_id)

    return unload_ok
