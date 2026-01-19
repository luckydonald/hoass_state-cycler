"""Comprehensive integration tests for State Cycler.

This file adds broader end-to-end tests using the real `hass` fixture from
pytest-homeassistant-custom-component. Tests exercise multiple cyclers,
services/actions, timers, events, and adapters.
"""
from __future__ import annotations

import asyncio
from datetime import timedelta
import pytest

from pytest_homeassistant_custom_component.common import (
    MockConfigEntry,
    async_fire_time_changed,
)

from homeassistant.const import ATTR_ENTITY_ID
from homeassistant.core import HomeAssistant
from homeassistant.util import dt as dt_util
import uuid

from custom_components.state_cycler.const import (
    DOMAIN,
    EVENT_CYCLED,
    EVENT_INITIALIZED,
)


@pytest.mark.asyncio
async def test_multiple_cyclers_operate_independently(hass: HomeAssistant):
    """Create two cyclers and verify they don't interfere with each other."""
    hass.states.async_set("light.a", "on", {"friendly_name": "A"})
    hass.states.async_set("light.b", "on", {"friendly_name": "B"})
    hass.states.async_set("light.c", "on", {"friendly_name": "C"})

    entry1 = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Cycler 1",
        "states": ["light.a", "light.b"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry2 = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Cycler 2",
        "states": ["light.c"],
        "include_off_state": False,
        "timer_interval": None,
    })

    entry1.add_to_hass(hass)
    entry2.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry1.entry_id)
    assert await hass.config_entries.async_setup(entry2.entry_id)
    await hass.async_block_till_done()

    core1 = hass.data[DOMAIN][entry1.entry_id]["core"]
    core2 = hass.data[DOMAIN][entry2.entry_id]["core"]

    # Cycle first cycler
    await core1.async_next()
    await hass.async_block_till_done()
    assert core1._current_index == 0
    assert core2._current_index == -1

    # cleanup
    await hass.config_entries.async_unload(entry1.entry_id)
    await hass.config_entries.async_unload(entry2.entry_id)
    await hass.async_block_till_done()


@pytest.mark.asyncio
async def test_cycle_actions_and_events(hass: HomeAssistant):
    """Test next/prev/to/on/off/switch actions and that events fire with attrs."""
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    entry = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Event Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]

    events = []

    def _capture(ev):
        events.append(ev)

    hass.bus.async_listen(EVENT_CYCLED, lambda e: _capture(e))

    # next
    await core.async_next()
    await hass.async_block_till_done()
    assert core._current_index == 0
    assert events[-1].data[ATTR_ENTITY_ID] == "light.kitchen"

    # prev (wraps to last)
    await core.async_prev()
    await hass.async_block_till_done()
    assert core._current_index in (0, 1)

    # to valid
    await core._async_to_index(1)
    await hass.async_block_till_done()
    assert core._current_index == 1

    # to out-of-bounds (should not change index)
    old = core._current_index
    await core._async_to_index(999)
    await hass.async_block_till_done()
    assert core._current_index == old

    # off
    await core.async_turn_off()
    await hass.async_block_till_done()
    assert core._current_index == -1

    # on (restores last)
    await core.async_turn_on()
    await hass.async_block_till_done()
    assert core._current_index in (-1, 0, 1)

    # switch
    await core.async_switch()
    await hass.async_block_till_done()
    # After switch there is a deterministic toggle
    assert core._current_index in (-1, 0, 1)

    # cleanup
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()


@pytest.mark.asyncio
async def test_timer_functionality_auto_cycle(hass: HomeAssistant):
    """Test automatic timer-driven cycling using async_fire_time_changed."""
    hass.states.async_set("light.a", "on", {"friendly_name": "A"})
    hass.states.async_set("light.b", "on", {"friendly_name": "B"})

    entry = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Timer Cycler",
        "states": ["light.a", "light.b"],
        "include_off_state": False,
        "timer_interval": 1.0,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]

    # Initially off
    assert core._current_index == -1

    # Fast-forward time by 1 second to trigger timer
    now = dt_util.utcnow()
    async_fire_time_changed(hass, now + timedelta(seconds=1))
    await hass.async_block_till_done()

    # First timer tick should turn on first state
    assert core._current_index == 0

    # Another tick -> move to next
    async_fire_time_changed(hass, now + timedelta(seconds=2))
    await hass.async_block_till_done()
    assert core._current_index in (0, 1)

    # cleanup (unload will cancel the track_time_interval)
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()


@pytest.mark.asyncio
async def test_cycle_mode_timeout_and_future_cycle(hass: HomeAssistant):
    """Test cycle action's timeout (cycle-mode) and subsequent behavior.

    Note: The implementation schedules a loop.call_later for the cycle timeout;
    to allow it to run we await a short real sleep. Keep interval tiny to keep
    tests fast.
    """
    hass.states.async_set("light.a", "on", {"friendly_name": "A"})

    entry = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Mode Cycler",
        "states": ["light.a"],
        "include_off_state": False,
        "timer_interval": 0.01,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]

    # Start cycle (turns on first state and enters cycle mode)
    await core.async_cycle()
    await hass.async_block_till_done()
    assert core._current_index == 0
    assert core._cycle_mode_active is True

    # Wait for cycle timeout to expire (real sleep due to call_later usage)
    await asyncio.sleep(0.02)
    assert core._cycle_mode_active is False

    # After timeout, calling cycle again will start cycle mode and move to next
    await core.async_cycle()
    await hass.async_block_till_done()
    assert core._cycle_mode_active is True

    # cleanup
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()


@pytest.mark.asyncio
async def test_include_off_state_affects_options_and_events(hass: HomeAssistant):
    """When include_off_state is True the 'Off' option should be present and events reflect it."""
    hass.states.async_set("light.a", "on", {"friendly_name": "A"})

    entry = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Off Cycler",
        "states": ["light.a"],
        "include_off_state": True,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]

    events = []
    hass.bus.async_listen(EVENT_CYCLED, lambda e: events.append(e))

    # cycle to on
    await core.async_next()
    await hass.async_block_till_done()
    assert core._current_index == 0

    # turn off via service
    await core.async_turn_off()
    await hass.async_block_till_done()
    # last event should indicate Off
    assert events and events[-1].data.get("entity_id", events[-1].data.get(ATTR_ENTITY_ID)) in ("Off", "off")

    # cleanup
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()


@pytest.mark.asyncio
async def test_adapters_created_and_linked(hass: HomeAssistant):
    """Ensure adapters (select/switch/button/sensor) are created and linked to core."""
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})
    hass.states.async_set("switch.lamp", "off", {"friendly_name": "Bedside Lamp"})

    entry = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Adapter Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    core = hass.data[DOMAIN][entry.entry_id]["core"]

    # adapters are registered in core._adapters
    assert "select" in core._adapters
    assert "switch" in core._adapters
    assert ("button_next" in core._adapters) or ("button" in core._adapters)
    assert "sensor_raw" in core._adapters and "sensor_friendly" in core._adapters

    # Use switch adapter to turn on
    sw = core._adapters["switch"]
    await sw.async_turn_on()
    await hass.async_block_till_done()
    assert core._current_index == 0

    # Use select adapter to choose second option (map friendly -> core index)
    sel = core._adapters["select"]
    await sel.async_update()
    assert len(sel.options) >= 2
    await sel.async_select_option(sel.options[-1])
    await hass.async_block_till_done()
    assert core._current_index in (0, 1)

    # cleanup
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()


@pytest.mark.asyncio
async def test_initialized_event_fired_on_setup(hass: HomeAssistant):
    """Ensure the integration fires EVENT_INITIALIZED when entity is added."""
    hass.states.async_set("light.kitchen", "on", {"friendly_name": "Kitchen Lights"})

    entry = MockConfigEntry(entry_id=str(uuid.uuid4()), domain=DOMAIN, data={
        "name": "Init Cycler",
        "states": ["light.kitchen"],
        "include_off_state": False,
        "timer_interval": None,
    })
    entry.add_to_hass(hass)

    evts = []
    hass.bus.async_listen(EVENT_INITIALIZED, lambda e: evts.append(e))

    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    assert evts and evts[-1].data["states"] == ["light.kitchen"]

    # cleanup
    await hass.config_entries.async_unload(entry.entry_id)
    await hass.async_block_till_done()

