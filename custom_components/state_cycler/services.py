"""Services for State Cycler."""

from __future__ import annotations

import logging

from homeassistant.core import HomeAssistant, ServiceCall

from .const import LOG_NAME

_LOGGER = logging.getLogger(LOG_NAME)

# Define your service schemas here
# Example:
# SERVICE_EXAMPLE = "example_service"
# SERVICE_EXAMPLE_SCHEMA = None


async def async_setup_services(hass: HomeAssistant) -> None:
    """Set up services for State Cycler."""

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
    """Unload services for State Cycler."""
    # Unregister your services here
    # hass.services.async_remove(DOMAIN, SERVICE_EXAMPLE)

    _LOGGER.debug("Services unloaded")
