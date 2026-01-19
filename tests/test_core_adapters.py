import asyncio
import pytest
from unittest.mock import Mock, AsyncMock

from homeassistant.core import HomeAssistant
from homeassistant.config_entries import ConfigEntry

from custom_components.state_cycler.state_cycler import StateCyclerEntity
from custom_components.state_cycler.select import StateCyclerSelect
from custom_components.state_cycler.switch import StateCyclerSwitch
from custom_components.state_cycler.button import StateCyclerNextButton, StateCyclerPrevButton


@pytest.fixture
def hass():
    hass = Mock(spec=HomeAssistant)
    # Provide the data mapping expected by pytest-homeassistant-cusom_component plugin
    hass.data = {"custom_components": {}}
    # minimal bus and services used by core
    hass.bus = Mock()
    hass.services = Mock()
    hass.services.async_call = AsyncMock()
    # states mapping: provide a simple dict-like object with get
    class StatesDict(dict):
        def get(self, key, default=None):
            return super().get(key, default)
    hass.states = StatesDict()
    # event loop
    hass.loop = asyncio.get_event_loop()
    return hass


@pytest.fixture
def config_entry():
    entry = Mock(spec=ConfigEntry)
    entry.entry_id = "test_entry"
    entry.data = {
        "name": "Test Cycler",
        "states": ["light.kitchen", "switch.lamp"],
        "include_off_state": False,
        "timer_interval": None,
    }
    return entry


@pytest.mark.asyncio
async def test_core_registers_and_select_syncs(hass, config_entry):
    # prepare friendly names in hass.states
    hass.states["light.kitchen"] = Mock(attributes={"friendly_name": "Kitchen Lights"})
    hass.states["switch.lamp"] = Mock(attributes={"friendly_name": "Bedside Lamp"})

    # create core
    core = StateCyclerEntity(hass, config_entry)
    assert hass.data["state_cycler"][config_entry.entry_id]["core"] is core

    # create select adapter (it should register with core)
    selector = StateCyclerSelect(hass, config_entry)
    # registration
    assert "select" in core._adapters
    assert core._adapters["select"] is selector

    # core starts with index -1 (off)
    assert core._current_index == -1
    assert selector.current_option is None or selector.current_option == "Off"

    # cycle next (turn on first state)
    await core.async_next()

    # selector should reflect the selected friendly name
    assert selector.current_option in ("Kitchen Lights", "Kitchen Lights — light.kitchen")
    # core state should be the first machine id
    assert core._current_index == 0


@pytest.mark.asyncio
async def test_select_maps_back_to_core(hass, config_entry):
    hass.states["light.kitchen"] = Mock(attributes={"friendly_name": "Kitchen Lights"})
    hass.states["switch.lamp"] = Mock(attributes={"friendly_name": "Bedside Lamp"})

    core = StateCyclerEntity(hass, config_entry)
    selector = StateCyclerSelect(hass, config_entry)

    # ensure options built
    await selector.async_update()
    assert len(selector.options) >= 2

    # pick the first option and instruct selector to perform it
    first_option = selector.options[0]
    # if include_off was False, first_option corresponds to Kitchen Lights
    await selector.async_select_option(first_option)

    # core should now have index 0
    assert core._current_index == 0


@pytest.mark.asyncio
async def test_switch_and_buttons_control_core(hass, config_entry):
    hass.states["light.kitchen"] = Mock(attributes={"friendly_name": "Kitchen Lights"})
    hass.states["switch.lamp"] = Mock(attributes={"friendly_name": "Bedside Lamp"})

    core = StateCyclerEntity(hass, config_entry)
    sw = StateCyclerSwitch(hass, config_entry)
    btn_next = StateCyclerNextButton(hass, config_entry)
    btn_prev = StateCyclerPrevButton(hass, config_entry)

    # initial off
    assert core._current_index == -1

    # switch on -> core turns on first state
    await sw.async_turn_on()
    assert core._current_index == 0

    # next button increments
    await btn_next.async_press()
    assert core._current_index == 1

    # prev button decrements (wraps)
    await btn_prev.async_press()
    # after prev, should be 0 or wrap depending on implementation
    assert core._current_index in (0, len(core._states) - 1)

    # switch off -> core off
    await sw.async_turn_off()
    assert core._current_index == -1
