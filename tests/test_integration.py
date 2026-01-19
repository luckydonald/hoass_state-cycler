"""Integration tests for State Cycler using the real Home Assistant `hass` fixture.

These tests run the integration's `async_setup_entry` and exercise the core
entity behavior (setup, cycling, unload) against a full hass instance
provided by pytest-homeassistant-custom-component.
"""

import pytest

from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.state_cycler.const import DOMAIN


@pytest.mark.asyncio
async def test_integration_setup_and_cycle(hass):
    """Test setting up the integration and cycling through states using real hass fixtures."""
    # Prepare underlying entities so the core can resolve friendly names
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    # Create a proper MockConfigEntry and add it to hass
    entry = MockConfigEntry(domain=DOMAIN, data={
        "name": "Integration Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    # Use hass config entry setup (this calls our integration's async_setup_entry)
    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    # Ensure hass.data has the integration data and the core entity
    assert DOMAIN in hass.data
    assert entry.entry_id in hass.data[DOMAIN]
    core = hass.data[DOMAIN][entry.entry_id]["core"]
    assert core is not None

    # Ensure entity was added
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
    # The core primary state should reflect the underlying entity id
    assert state2.state == "light.kitchen"

    # Unload the integration via hass config_entries unload
    assert await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()
    assert entry.entry_id not in hass.data[DOMAIN]
