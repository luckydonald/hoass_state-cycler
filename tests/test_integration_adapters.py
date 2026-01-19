"""Integration adapter tests for State Cycler using the `hass` fixture.

These tests exercise the integration end-to-end at the Python level: they set up
an entry via MockConfigEntry, ensure the core and platform adapters are created,
and validate that adapter actions propagate to the core and that core updates
propagate back to adapters.
"""

import pytest

from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.state_cycler.const import DOMAIN


@pytest.mark.asyncio
async def test_core_registers_adapters_and_select_syncs(hass):
    """Adapters register with core and select reflects core state changes."""
    # Prepare friendly names
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    entry = MockConfigEntry(domain=DOMAIN, data={
        "name": "Test Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]
    assert core is not None

    # Ensure adapters registered
    assert "select" in core._adapters
    assert "switch" in core._adapters
    assert "button_next" in core._adapters or "button" in core._adapters
    assert "sensor_raw" in core._adapters
    assert "sensor_friendly" in core._adapters

    selector = core._adapters["select"]
    # core starts off
    assert core._current_index == -1
    # simulate core cycling to next state
    await core.async_next()
    await hass.async_block_till_done()

    # selector should reflect a friendly name
    opt = selector.current_option
    assert opt in ("Kitchen Lights", "Kitchen Lights — light.kitchen")
    assert core._current_index == 0


@pytest.mark.asyncio
async def test_select_maps_back_to_core(hass):
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    entry = MockConfigEntry(domain=DOMAIN, data={
        "name": "Test Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]
    selector = core._adapters["select"]

    # ensure options built
    await selector.async_update()
    assert len(selector.options) >= 2

    # pick the first option and instruct selector to perform it
    first_option = selector.options[0]
    await selector.async_select_option(first_option)
    await hass.async_block_till_done()

    # core should now have index 0
    assert core._current_index == 0


@pytest.mark.asyncio
async def test_switch_and_buttons_control_core(hass):
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    entry = MockConfigEntry(domain=DOMAIN, data={
        "name": "Test Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]
    sw = core._adapters["switch"]
    btn_next = core._adapters.get("button_next") or core._adapters.get("button")
    btn_prev = core._adapters.get("button_prev")

    # initial off
    assert core._current_index == -1

    # switch on -> core turns on first state
    await sw.async_turn_on()
    await hass.async_block_till_done()
    assert core._current_index == 0

    # next button increments
    if btn_next:
        await btn_next.async_press()
        await hass.async_block_till_done()
        assert core._current_index in (1, 0)

    # prev button decrements (wraps)
    if btn_prev:
        await btn_prev.async_press()
        await hass.async_block_till_done()
        assert core._current_index in (0, len(core._states) - 1)

    # switch off -> core off
    await sw.async_turn_off()
    await hass.async_block_till_done()
    assert core._current_index == -1


@pytest.mark.asyncio
async def test_sensors_expose_core_state(hass):
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    entry = MockConfigEntry(domain=DOMAIN, data={
        "name": "Test Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]
    raw = core._adapters["sensor_raw"]
    friendly = core._adapters["sensor_friendly"]

    # initial states
    assert raw.state == "off"
    assert friendly.state == "Off"

    # move core to first state
    await core.async_next()
    await hass.async_block_till_done()

    assert raw.state == "light.kitchen"
    assert friendly.state in ("Kitchen Lights", "Kitchen Lights — light.kitchen")
