"""Config flow for State Cycler integration."""

from __future__ import annotations

import logging
from typing import Any

from homeassistant import config_entries
from homeassistant.core import callback
from homeassistant.data_entry_flow import FlowResult
import voluptuous as vol

from .const import (
    CONF_INCLUDE_OFF_STATE,
    CONF_STATES,
    CONF_TIMER_INTERVAL,
    DEFAULT_INCLUDE_OFF_STATE,
    DEFAULT_NAME,
    DOMAIN,
)

_LOGGER = logging.getLogger(__name__)


class StateCyclerConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for State Cycler."""

    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> FlowResult:
        """Handle the initial step."""
        if user_input is not None:
            return self.async_create_entry(
                title=user_input.get("name", DEFAULT_NAME),
                data=user_input,
            )

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema(
                {
                    vol.Required("name", default=DEFAULT_NAME): str,
                    vol.Optional(CONF_STATES, default=[]): vol.All(list, [str]),
                    vol.Optional(
                        CONF_INCLUDE_OFF_STATE, default=DEFAULT_INCLUDE_OFF_STATE
                    ): bool,
                    vol.Optional(CONF_TIMER_INTERVAL): vol.All(
                        vol.Coerce(float), vol.Range(min=0.1)
                    ),
                }
            ),
        )

    @staticmethod
    @callback
    def async_get_options_flow(
        config_entry: config_entries.ConfigEntry,
    ) -> StateCyclerOptionsFlow:
        """Get the options flow for this handler."""
        return StateCyclerOptionsFlow(config_entry)


class StateCyclerOptionsFlow(config_entries.OptionsFlow):
    """Handle options flow for State Cycler."""

    def __init__(self, config_entry: config_entries.ConfigEntry) -> None:
        """Initialize options flow."""
        self.config_entry = config_entry

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> FlowResult:
        """Manage the options."""
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Optional(
                        CONF_STATES,
                        default=self.config_entry.data.get(CONF_STATES, []),
                    ): vol.All(list, [str]),
                    vol.Optional(
                        CONF_INCLUDE_OFF_STATE,
                        default=self.config_entry.data.get(
                            CONF_INCLUDE_OFF_STATE, DEFAULT_INCLUDE_OFF_STATE
                        ),
                    ): bool,
                    vol.Optional(
                        CONF_TIMER_INTERVAL,
                        default=self.config_entry.data.get(CONF_TIMER_INTERVAL),
                    ): vol.All(vol.Coerce(float), vol.Range(min=0.1)),
                }
            ),
        )
