"""State Cycler main logic."""

from __future__ import annotations
import asyncio
import logging
from datetime import timedelta
from typing import Any

from homeassistant.const import (
    ATTR_ENTITY_ID,
    SERVICE_TURN_OFF,
    SERVICE_TURN_ON,
    STATE_OFF,
    STATE_ON,
    STATE_UNAVAILABLE,
    STATE_UNKNOWN,
)
from homeassistant.core import HomeAssistant, ServiceCall, callback
from homeassistant.helpers.entity import Entity
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.event import async_track_time_interval
from homeassistant.helpers.restore_state import RestoreEntity
from homeassistant.helpers.typing import ConfigType
import voluptuous as vol

from .const import (
    ATTR_INDEX,
    ATTR_INCLUDE_OFF_STATE,
    ATTR_LAST_INDEX,
    ATTR_LAST_STATE,
    ATTR_STATE,
    ATTR_STATE_FRIENDLY,
    ATTR_STATES,
    ATTR_TIMER_INTERVAL,
    ATTR_TOGGLE_STATE,
    CONF_INCLUDE_OFF_STATE,
    CONF_STATES,
    CONF_TIMER_INTERVAL,
    DEFAULT_INCLUDE_OFF_STATE,
    DEFAULT_NAME,
    DOMAIN,
    EVENT_CYCLE_TIMEOUT,
    EVENT_CYCLED,
    EVENT_INITIALIZED,
    SERVICE_CYCLE,
    SERVICE_NEXT,
    SERVICE_OFF,
    SERVICE_ON,
    SERVICE_PREV,
    SERVICE_SWITCH,
    SERVICE_TO,
)

_LOGGER = logging.getLogger(__name__)


async def async_setup_platform(
    hass: HomeAssistant,
    config: ConfigType,
    async_add_entities: AddEntitiesCallback,
    discovery_info: dict[str, Any] | None = None,
) -> None:
    """Set up the State Cycler platform."""
    # Platform setup is handled via config entries
    pass


async def async_setup_entry(
    hass: HomeAssistant,
    config_entry: ConfigType,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up State Cycler entities from config entry."""
    entity = StateCyclerEntity(hass, config_entry)
    async_add_entities([entity], True)

    # Register services
    platform = entity.platform

    platform.async_register_entity_service(
        SERVICE_NEXT,
        {},
        "async_next",
    )

    platform.async_register_entity_service(
        SERVICE_PREV,
        {},
        "async_prev",
    )

    platform.async_register_entity_service(
        SERVICE_TO,
        {vol.Required(ATTR_INDEX): vol.Coerce(int)},
        "async_to",
    )

    platform.async_register_entity_service(
        SERVICE_OFF,
        {},
        "async_turn_off",
    )

    platform.async_register_entity_service(
        SERVICE_ON,
        {},
        "async_turn_on",
    )

    platform.async_register_entity_service(
        SERVICE_SWITCH,
        {},
        "async_switch",
    )

    platform.async_register_entity_service(
        SERVICE_CYCLE,
        {},
        "async_cycle",
    )


class StateCyclerEntity(RestoreEntity, Entity):
    """Representation of a State Cycler entity."""

    _attr_should_poll = False

    def __init__(self, hass: HomeAssistant, config_entry: ConfigType) -> None:
        """Initialize the State Cycler entity."""
        self.hass = hass
        self._config_entry = config_entry
        self._attr_unique_id = config_entry.entry_id
        self._attr_name = config_entry.data.get("name", DEFAULT_NAME)

        # State management
        self._states: list[str] = config_entry.data.get(CONF_STATES, [])
        self._current_index: int = -1  # -1 means off
        self._last_index: int | None = None
        self._include_off_state: bool = config_entry.data.get(
            CONF_INCLUDE_OFF_STATE, DEFAULT_INCLUDE_OFF_STATE
        )
        self._timer_interval: float | None = config_entry.data.get(CONF_TIMER_INTERVAL)

        # Entity state tracking (for restoration)
        self._entity_states: dict[str, dict[str, Any]] = {}

        # Timer management
        self._timer_cancel: Any | None = None
        self._cycle_mode_active: bool = False
        self._cycle_timer_cancel: Any | None = None

    async def async_added_to_hass(self) -> None:
        """Run when entity about to be added to hass."""
        await super().async_added_to_hass()

        # Restore previous state
        last_state = await self.async_get_last_state()
        if last_state and last_state.state != STATE_UNAVAILABLE:
            try:
                self._current_index = int(last_state.attributes.get(ATTR_INDEX, -1))
                self._last_index = last_state.attributes.get(ATTR_LAST_INDEX)
                self._include_off_state = last_state.attributes.get(
                    ATTR_INCLUDE_OFF_STATE, DEFAULT_INCLUDE_OFF_STATE
                )
            except (ValueError, TypeError):
                _LOGGER.warning("Could not restore state for %s", self.entity_id)

        # Fire initialized event
        self.hass.bus.async_fire(
            EVENT_INITIALIZED,
            {
                ATTR_STATES: self._states,
                ATTR_INDEX: self._current_index,
                ATTR_ENTITY_ID: self._get_current_entity_id(),
            },
        )

        # Start timer if configured
        if self._timer_interval:
            self._start_timer()

    async def async_will_remove_from_hass(self) -> None:
        """Run when entity will be removed from hass."""
        self._cancel_timers()

    @property
    def state(self) -> str:
        """Return the state of the entity."""
        if self._current_index == -1:
            return STATE_OFF
        if 0 <= self._current_index < len(self._states):
            return self._states[self._current_index]
        return STATE_OFF

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        """Return entity specific state attributes."""
        attrs = {
            ATTR_STATE: self.state,
            ATTR_STATE_FRIENDLY: self._get_state_friendly_name(),
            ATTR_INDEX: self._current_index,
            ATTR_TOGGLE_STATE: self._current_index != -1,
            ATTR_INCLUDE_OFF_STATE: self._include_off_state,
            ATTR_TIMER_INTERVAL: self._timer_interval,
            ATTR_STATES: self._states,
        }

        if self._last_index is not None:
            attrs[ATTR_LAST_STATE] = (
                self._states[self._last_index]
                if 0 <= self._last_index < len(self._states)
                else STATE_OFF
            )
            attrs[ATTR_LAST_INDEX] = self._last_index

        return attrs

    def _get_current_entity_id(self) -> str:
        """Get current entity ID or 'Off'."""
        if self._current_index == -1:
            return "Off"
        if 0 <= self._current_index < len(self._states):
            return self._states[self._current_index]
        return "Off"

    def _get_state_friendly_name(self) -> str:
        """Get friendly name of current state."""
        if self._current_index == -1:
            return "Off"
        if 0 <= self._current_index < len(self._states):
            entity_id = self._states[self._current_index]
            state = self.hass.states.get(entity_id)
            if state:
                return state.attributes.get("friendly_name", entity_id)
            return entity_id
        return "Off"

    async def _save_entity_state(self, entity_id: str) -> None:
        """Save the current state of an entity before turning it off."""
        state = self.hass.states.get(entity_id)
        if state and state.state not in (STATE_UNAVAILABLE, STATE_UNKNOWN):
            self._entity_states[entity_id] = {
                "state": state.state,
                "attributes": dict(state.attributes),
            }

    async def _restore_entity_state(self, entity_id: str) -> None:
        """Restore the saved state of an entity."""
        saved_state = self._get_saved_state(entity_id)
        domain = entity_id.split(".")[0]
        if saved_state:
            if saved_state["state"] == "on":
                await self.hass.services.async_call(
                    domain,
                    "turn_on",
                    {"entity_id": entity_id},
                    blocking=True,
                )
            elif domain == "scene":
                await self.hass.services.async_call(
                    domain,
                    "turn_on",
                    {"entity_id": entity_id},
                    blocking=True,
                )
            else:
                await self.hass.services.async_call(
                    domain,
                    "turn_on",
                    {
                        "entity_id": entity_id,
                        # Add attribute restoration logic here if needed
                    },
                    blocking=True,
                )

    def _get_saved_state(self, entity_id: str) -> dict[str, Any] | None:
        """Get the saved state for an entity."""
        return self._entity_states.get(entity_id)

    async def _turn_off_entity(self, entity_id: str) -> None:
        """Turn off an entity."""
        await self._save_entity_state(entity_id)
        domain = entity_id.split(".")[0]

        if domain != "scene":  # Scenes can't be turned off
            await self.hass.services.async_call(
                domain,
                SERVICE_TURN_OFF,
                {ATTR_ENTITY_ID: entity_id},
                blocking=True,
            )

    async def _turn_on_entity(self, entity_id: str) -> None:
        """Turn on an entity, restoring state if available."""
        await self._restore_entity_state(entity_id)

    async def _cycle_to_index(
        self,
        new_index: int,
        direction: str = "next",
        mode: str = "direct",
        command: str = "to",
    ) -> None:
        """Cycle to a specific index."""
        if not 0 <= new_index < len(self._states):
            _LOGGER.error("Index %d out of bounds for %s", new_index, self.entity_id)
            return

        old_index = self._current_index
        old_entity_id = self._get_current_entity_id()

        # Turn off old state
        if old_index != -1 and 0 <= old_index < len(self._states):
            await self._turn_off_entity(self._states[old_index])

        # Turn on new state
        await self._turn_on_entity(self._states[new_index])

        # Update state
        self._last_index = old_index
        self._current_index = new_index

        # Calculate wrap and difference
        index_diff = new_index - (old_index if old_index != -1 else -1)
        wrapped = False

        if direction == "next" and old_index != -1 and new_index < old_index:
            wrapped = True
        elif direction == "prev" and old_index != -1 and new_index > old_index:
            wrapped = True

        # Fire event
        self.hass.bus.async_fire(
            EVENT_CYCLED,
            {
                ATTR_ENTITY_ID: self._states[new_index],
                ATTR_INDEX: new_index,
                "direction": direction,
                "index_difference": index_diff,
                "wrapped": wrapped,
                ATTR_LAST_INDEX: old_index,
                "last_entity_id": old_entity_id,
                "timer": self._timer_interval if mode == "timer" else None,
                "mode": mode,
                "command": command,
            },
        )

        self.async_write_ha_state()

    async def async_next(self, call: ServiceCall | None = None) -> None:
        """Cycle to next state."""
        if not self._states:
            return

        if self._current_index == -1:
            new_index = 0
        else:
            new_index = (self._current_index + 1) % len(self._states)

        await self._cycle_to_index(new_index, "next", "direct", SERVICE_NEXT)

    async def async_prev(self, call: ServiceCall | None = None) -> None:
        """Cycle to previous state."""
        if not self._states:
            return

        if self._current_index == -1:
            new_index = len(self._states) - 1
        else:
            new_index = (self._current_index - 1) % len(self._states)

        await self._cycle_to_index(new_index, "prev", "direct", SERVICE_PREV)

    async def async_to(self, call: ServiceCall) -> None:
        """Cycle to specific index."""
        index = call.data[ATTR_INDEX]

        if not 0 <= index < len(self._states):
            _LOGGER.error("Index %d out of bounds for %s", index, self.entity_id)
            return

        direction = "next" if index > self._current_index else "prev"
        await self._cycle_to_index(index, direction, "direct", SERVICE_TO)

    async def async_turn_off(self, **kwargs: Any) -> None:
        """Turn off all states."""
        old_index = self._current_index
        old_entity_id = self._get_current_entity_id()

        if old_index != -1 and 0 <= old_index < len(self._states):
            await self._turn_off_entity(self._states[old_index])

        self._last_index = old_index
        self._current_index = -1

        # Fire event
        self.hass.bus.async_fire(
            EVENT_CYCLED,
            {
                ATTR_ENTITY_ID: "Off",
                ATTR_INDEX: -1,
                "direction": "next" if self._include_off_state else "prev",
                "index_difference": -1,
                "wrapped": False,
                ATTR_LAST_INDEX: old_index,
                "last_entity_id": old_entity_id,
                "timer": None,
                "mode": "toggle",
                "command": SERVICE_OFF,
            },
        )

        self.async_write_ha_state()

    async def async_turn_on(self, **kwargs: Any) -> None:
        """Turn on last state or reapply current state."""
        if self._current_index != -1:
            # Reapply current state
            await self._turn_on_entity(self._states[self._current_index])
        elif self._last_index is not None and 0 <= self._last_index < len(self._states):
            # Restore last state
            await self._cycle_to_index(self._last_index, "next", "toggle", SERVICE_ON)
        elif self._states:
            # Turn on first state
            await self._cycle_to_index(0, "next", "toggle", SERVICE_ON)

    async def async_switch(self, call: ServiceCall | None = None) -> None:
        """Toggle between on and off."""
        if self._current_index == -1:
            await self.async_turn_on()
        else:
            await self.async_turn_off()

    async def async_cycle(self, call: ServiceCall | None = None) -> None:
        """Cycle action with timer logic."""
        if self._current_index == -1:
            # Turn on first state
            if self._states:
                await self._cycle_to_index(0, "next", "cycle", SERVICE_CYCLE)
            self._cycle_mode_active = True
        elif self._cycle_mode_active:
            # Continue cycling
            await self.async_next()
        else:
            # Start cycle mode
            self._cycle_mode_active = True
            await self.async_next()

        # Reset cycle mode timer
        self._reset_cycle_timer()

    def _reset_cycle_timer(self) -> None:
        """Reset the cycle mode timer."""
        if self._cycle_timer_cancel:
            self._cycle_timer_cancel()

        if self._timer_interval:
            self._cycle_timer_cancel = self.hass.loop.call_later(
                self._timer_interval, lambda: asyncio.create_task(self._cycle_timeout())
            )

    async def _cycle_timeout(self) -> None:
        """Handle cycle timeout - next cycle will turn off."""
        self._cycle_mode_active = False
        self._cycle_timer_cancel = None

        self.hass.bus.async_fire(
            EVENT_CYCLE_TIMEOUT,
            {
                ATTR_ENTITY_ID: self._get_current_entity_id(),
                ATTR_INDEX: self._current_index,
            },
        )

    def _start_timer(self) -> None:
        """Start the automatic cycling timer."""
        if self._timer_interval and not self._timer_cancel:
            self._timer_cancel = async_track_time_interval(
                self.hass,
                self._timer_callback,
                timedelta(seconds=self._timer_interval),
            )

    @callback
    def _timer_callback(self, now: Any) -> None:
        """Handle timer callback."""
        asyncio.create_task(self._timer_next())

    async def _timer_next(self) -> None:
        """Cycle to next state via timer."""
        if not self._states:
            return

        if self._current_index == -1:
            new_index = 0
        else:
            new_index = (self._current_index + 1) % len(self._states)

        await self._cycle_to_index(new_index, "next", "timer", "timer")

    def _cancel_timers(self) -> None:
        """Cancel all timers."""
        if self._timer_cancel:
            self._timer_cancel()
            self._timer_cancel = None

        if self._cycle_timer_cancel:
            self._cycle_timer_cancel()
            self._cycle_timer_cancel = None
