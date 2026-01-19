"""Integration tests for State Cycler using the real Home Assistant `hass` fixture.

These tests run the integration's `async_setup_entry` and exercise the core
entity behavior (setup, cycling, unload) against a full hass instance
provided by pytest-homeassistant-custom-component.
"""
from unittest.mock import Mock

import pytest

from homeassistant.config_entries import ConfigEntry

from custom_components.state_cycler import async_setup_entry, async_unload_entry
from custom_components.state_cycler.const import DOMAIN


@pytest.mark.asyncio
async def test_integration_setup_and_cycle(hass):
    """Test setting up the integration and cycling through states."""
    # Prepare underlying entities so the core can resolve friendly names
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    # Create a minimal fake config entry
    entry = Mock(spec=ConfigEntry)
    entry.entry_id = "integ1"
    entry.data = {
        "name": "Integration Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    }

    # Set up the integration
    result = await async_setup_entry(hass, entry)
    assert result is True

    # Ensure hass.data has the integration data and the core entity
    assert DOMAIN in hass.data
    assert entry.entry_id in hass.data[DOMAIN]
    core = hass.data[DOMAIN][entry.entry_id]["core"]
    assert core is not None

    # Allow any tasks to finish and ensure entity was added
    await hass.async_block_till_done()
    assert core.entity_id is not None

    state = hass.states.get(core.entity_id)
    assert state is not None
    # Initial state should be 'off' (machine value)
    assert state.state == "off"

    # Cycle to next state (first configured state)
    await core.async_next()
    await hass.async_block_till_done()

    state2 = hass.states.get(core.entity_id)
    assert state2 is not None
    # The core primary state should reflect the underlying entity id (lowercase)
    assert state2.state in ("light.kitchen", "light.kitchen")

    # Unload the integration
    ok = await async_unload_entry(hass, entry)
    assert ok is True
    assert entry.entry_id not in hass.data[DOMAIN]
