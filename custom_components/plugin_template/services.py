"""Services for Plugin Template."""

from __future__ import annotations

import logging
from typing import Any

import voluptuous as vol

from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.helpers import config_validation as cv

from .const import DOMAIN, LOG_NAME

_LOGGER = logging.getLogger(LOG_NAME)

# Define your service schemas here
# Example:
# SERVICE_EXAMPLE = "example_service"
# SERVICE_EXAMPLE_SCHEMA = vol.Schema({
#     vol.Required("entity_id"): cv.entity_id,
#     vol.Optional("param"): cv.string,
# })


async def async_setup_services(hass: HomeAssistant) -> None:
    """Set up services for Plugin Template."""

    async def handle_example_service(call: ServiceCall) -> None:
        """Handle the example service call."""
        # Add your service logic here
        _LOGGER.debug("Example service called with data: %s", call.data)
        pass

    # Register your services here
    # hass.services.async_register(
    #     DOMAIN,
    #     SERVICE_EXAMPLE,
    #     handle_example_service,
    #     schema=SERVICE_EXAMPLE_SCHEMA,
    # )

    _LOGGER.debug("Services registered")


async def async_unload_services(hass: HomeAssistant) -> None:
    """Unload services for Plugin Template."""
    # Unregister your services here
    # hass.services.async_remove(DOMAIN, SERVICE_EXAMPLE)

    _LOGGER.debug("Services unloaded")

