"""Unit tests for StateCyclerEntity state-toggling logic.

All tests drive the core entity directly (no full HA platform setup), using the
real `hass` fixture for its event bus, async utilities, and state registry.
Concepts tested are taken directly from ai/query.md.

Tests that document spec behaviour not yet implemented are marked with a comment;
they will fail until the gap is fixed.
"""
from __future__ import annotations

from unittest.mock import MagicMock

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant

from custom_components.state_cycler.const import (
    ATTR_INCLUDE_OFF_STATE,
    ATTR_INDEX,
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
    DOMAIN,
    EVENT_CYCLE_TIMEOUT,
    EVENT_CYCLED,
)
from custom_components.state_cycler.state_cycler import StateCyclerEntity

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ENTITY_A = "light.a"
ENTITY_B = "light.b"
ENTITY_C = "light.c"
STATES = [ENTITY_A, ENTITY_B, ENTITY_C]


def _entry(
    entry_id: str = "eid",
    states: list[str] | None = None,
    include_off_state: bool = False,
    timer_interval: float | None = None,
    name: str = "Test Cycler",
) -> MagicMock:
    e = MagicMock(spec=ConfigEntry)
    e.entry_id = entry_id
    data: dict = {
        "name": name,
        CONF_STATES: states if states is not None else STATES,
        CONF_INCLUDE_OFF_STATE: include_off_state,
    }
    if timer_interval is not None:
        data[CONF_TIMER_INTERVAL] = timer_interval
    e.data = data
    return e


def _core(hass: HomeAssistant, **kwargs) -> StateCyclerEntity:
    entry = _entry(**kwargs)
    hass.data.setdefault(DOMAIN, {})
    hass.data[DOMAIN].setdefault(entry.entry_id, {})
    return StateCyclerEntity(hass, entry)


# ---------------------------------------------------------------------------
# next
# ---------------------------------------------------------------------------


class TestNext:
    async def test_from_off_goes_to_index_0(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_next()
        assert core._current_index == 0

    async def test_advances_one_step(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        assert core._current_index == 1

    async def test_wraps_from_last_to_first(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 2
        await core.async_next()
        assert core._current_index == 0

    async def test_records_previous_as_last_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        await core.async_next()
        assert core._last_index == 1

    async def test_noop_with_empty_states(self, hass: HomeAssistant) -> None:
        core = _core(hass, states=[])
        await core.async_next()
        assert core._current_index == -1

    async def test_fires_cycled_event(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        assert len(fired) == 1
        assert fired[0].data["command"] == "next"
        assert fired[0].data[ATTR_INDEX] == 1

    async def test_wrapped_true_on_wrap(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 2
        await core.async_next()
        await hass.async_block_till_done()
        assert fired[0].data["wrapped"] is True

    async def test_wrapped_false_on_normal_advance(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        assert fired[0].data["wrapped"] is False

    async def test_single_state_list_stays_at_0(self, hass: HomeAssistant) -> None:
        core = _core(hass, states=["light.only"])
        await core.async_next()
        assert core._current_index == 0
        await core.async_next()
        assert core._current_index == 0


# ---------------------------------------------------------------------------
# prev
# ---------------------------------------------------------------------------


class TestPrev:
    async def test_from_off_goes_to_last_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_prev()
        assert core._current_index == 2

    async def test_decrements_one_step(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 2
        await core.async_prev()
        assert core._current_index == 1

    async def test_wraps_from_first_to_last(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        await core.async_prev()
        assert core._current_index == 2

    async def test_records_previous_as_last_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 2
        await core.async_prev()
        assert core._last_index == 2

    async def test_noop_with_empty_states(self, hass: HomeAssistant) -> None:
        core = _core(hass, states=[])
        await core.async_prev()
        assert core._current_index == -1

    async def test_fires_cycled_event(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 2
        await core.async_prev()
        await hass.async_block_till_done()
        assert fired[0].data["command"] == "prev"
        assert fired[0].data[ATTR_INDEX] == 1

    async def test_wrapped_true_on_wrap(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_prev()
        await hass.async_block_till_done()
        assert fired[0].data["wrapped"] is True


# ---------------------------------------------------------------------------
# to
# ---------------------------------------------------------------------------


class TestTo:
    async def test_jumps_to_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core._async_to_index(2)
        assert core._current_index == 2

    async def test_jump_to_zero_from_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core._async_to_index(0)
        assert core._current_index == 0

    async def test_out_of_bounds_high_no_change(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        await core._async_to_index(99)
        assert core._current_index == 0

    async def test_negative_out_of_bounds_no_change(self, hass: HomeAssistant) -> None:
        # -1 means "off" but _async_to_index rejects it as out of bounds
        core = _core(hass)
        core._current_index = 0
        await core._async_to_index(-1)
        assert core._current_index == 0

    async def test_fires_event_with_command_to(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        await core._async_to_index(1)
        await hass.async_block_till_done()
        assert fired[0].data["command"] == "to"
        assert fired[0].data[ATTR_INDEX] == 1

    async def test_records_last_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        await core._async_to_index(2)
        assert core._last_index == 1


# ---------------------------------------------------------------------------
# off
# ---------------------------------------------------------------------------


class TestOff:
    async def test_sets_index_to_minus_one(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        await core.async_turn_off()
        assert core._current_index == -1

    async def test_records_last_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 2
        await core.async_turn_off()
        assert core._last_index == 2

    async def test_from_already_off_stays_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_turn_off()
        assert core._current_index == -1

    async def test_toggle_state_false_after_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        await core.async_turn_off()
        assert core.extra_state_attributes[ATTR_TOGGLE_STATE] is False

    async def test_fires_cycled_event_command_off(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_turn_off()
        await hass.async_block_till_done()
        assert fired[0].data["command"] == "off"
        assert fired[0].data[ATTR_INDEX] == -1
        assert fired[0].data["mode"] == "toggle"


# ---------------------------------------------------------------------------
# on
# ---------------------------------------------------------------------------


class TestOn:
    async def test_from_off_no_last_goes_to_first(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_turn_on()
        assert core._current_index == 0

    async def test_restores_last_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._last_index = 2
        await core.async_turn_on()
        assert core._current_index == 2

    async def test_reapplies_when_already_on_does_not_change_index(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        await core.async_turn_on()
        assert core._current_index == 1

    async def test_noop_with_empty_states_when_off(self, hass: HomeAssistant) -> None:
        core = _core(hass, states=[])
        await core.async_turn_on()
        assert core._current_index == -1

    async def test_full_cycle_off_on_restores(self, hass: HomeAssistant) -> None:
        """off → on (first) → off → on restores index 0."""
        core = _core(hass)
        await core.async_turn_on()   # → index 0
        await core.async_turn_off()  # → off, last=0
        await core.async_turn_on()   # → index 0 (restored)
        assert core._current_index == 0


# ---------------------------------------------------------------------------
# switch
# ---------------------------------------------------------------------------


class TestSwitch:
    async def test_off_turns_on(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_switch()
        assert core._current_index != -1

    async def test_on_turns_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        await core.async_switch()
        assert core._current_index == -1

    async def test_toggle_cycle_restores_state(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 2
        await core.async_switch()   # off, last=2
        await core.async_switch()   # on → restores 2
        assert core._current_index == 2

    async def test_toggle_state_reflects_switch(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        await core.async_switch()
        assert core.extra_state_attributes[ATTR_TOGGLE_STATE] is False
        await core.async_switch()
        assert core.extra_state_attributes[ATTR_TOGGLE_STATE] is True


# ---------------------------------------------------------------------------
# cycle
# ---------------------------------------------------------------------------


class TestCycle:
    async def test_from_off_turns_on_first_state(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_cycle()
        assert core._current_index == 0

    async def test_from_off_activates_cycle_mode(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_cycle()
        assert core._cycle_mode_active is True

    async def test_second_call_advances(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_cycle()  # index=0
        await core.async_cycle()  # index=1
        assert core._current_index == 1

    async def test_noop_with_empty_states(self, hass: HomeAssistant) -> None:
        core = _core(hass, states=[])
        await core.async_cycle()
        assert core._current_index == -1

    async def test_timeout_deactivates_cycle_mode(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_cycle()
        assert core._cycle_mode_active is True
        await core._cycle_timeout()
        assert core._cycle_mode_active is False

    async def test_timeout_fires_cycle_timeout_event(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLE_TIMEOUT, fired.append)
        core = _core(hass)
        core._current_index = 1
        await core._cycle_timeout()
        await hass.async_block_till_done()
        assert len(fired) == 1
        assert fired[0].data[ATTR_INDEX] == 1

    async def test_timeout_event_carries_current_entity_id(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLE_TIMEOUT, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core._cycle_timeout()
        await hass.async_block_till_done()
        assert fired[0].data["entity_id"] == ENTITY_A

    async def test_no_cycle_timer_without_timer_interval(self, hass: HomeAssistant) -> None:
        """Without timer_interval the cycle timeout handle is never set."""
        core = _core(hass)  # no timer_interval
        await core.async_cycle()
        assert core._cycle_timer_cancel is None

    async def test_after_timeout_next_cycle_turns_off(self, hass: HomeAssistant) -> None:
        """Spec (ai/query.md): after the cycle timeout the next async_cycle turns off.

        NOTE: Current implementation does NOT do this — it restarts cycle-forward
        instead. Fix requires tracking a 'pending-off' flag in _cycle_timeout and
        checking it in async_cycle.
        """
        core = _core(hass)
        await core.async_cycle()          # index=0, cycle_mode=True
        await core._cycle_timeout()       # cycle_mode=False
        await core.async_cycle()          # spec says: should turn off
        assert core._current_index == -1  # FAILS with current code (goes to 1 instead)

    async def test_cycle_mode_first_call_fires_cycle_mode_event(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        await core.async_cycle()
        await hass.async_block_till_done()
        assert fired[0].data["mode"] == "cycle"


# ---------------------------------------------------------------------------
# Attributes
# ---------------------------------------------------------------------------


class TestAttributes:
    async def test_state_off_initially(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert core.state == "off"

    async def test_state_returns_entity_id_when_active(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        assert core.state == ENTITY_A

    async def test_state_is_lowercased(self, hass: HomeAssistant) -> None:
        core = _core(hass, states=["LIGHT.UPPER"])
        core._current_index = 0
        assert core.state == "light.upper"

    async def test_index_when_active(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 1
        assert core.extra_state_attributes[ATTR_INDEX] == 1

    async def test_index_minus_one_when_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert core.extra_state_attributes[ATTR_INDEX] == -1

    async def test_toggle_state_true_when_on(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        assert core.extra_state_attributes[ATTR_TOGGLE_STATE] is True

    async def test_toggle_state_false_when_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert core.extra_state_attributes[ATTR_TOGGLE_STATE] is False

    async def test_states_list_in_attrs(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert core.extra_state_attributes[ATTR_STATES] == STATES

    async def test_include_off_state_false_by_default(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert core.extra_state_attributes[ATTR_INCLUDE_OFF_STATE] is False

    async def test_include_off_state_true_when_configured(self, hass: HomeAssistant) -> None:
        core = _core(hass, include_off_state=True)
        assert core.extra_state_attributes[ATTR_INCLUDE_OFF_STATE] is True

    async def test_timer_interval_none_when_not_configured(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert core.extra_state_attributes[ATTR_TIMER_INTERVAL] is None

    async def test_timer_interval_value_when_configured(self, hass: HomeAssistant) -> None:
        core = _core(hass, timer_interval=10.5)
        assert core.extra_state_attributes[ATTR_TIMER_INTERVAL] == 10.5

    async def test_last_state_absent_before_any_action(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        assert ATTR_LAST_STATE not in core.extra_state_attributes

    async def test_last_index_and_last_state_after_next(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        attrs = core.extra_state_attributes
        assert attrs[ATTR_LAST_INDEX] == 0
        assert attrs[ATTR_LAST_STATE] == ENTITY_A

    async def test_last_index_is_minus_one_when_turned_off_from_off(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        await core.async_turn_off()
        assert core.extra_state_attributes[ATTR_LAST_INDEX] == -1


# ---------------------------------------------------------------------------
# Cycled event fields
# ---------------------------------------------------------------------------


class TestCycledEventFields:
    async def test_all_required_fields_present(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        required = {
            "entity_id", "index", "direction", "index_difference",
            "wrapped", "last_index", "last_entity_id", "timer", "mode", "command",
        }
        assert required.issubset(fired[0].data.keys())

    async def test_mode_direct_on_next(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        assert fired[0].data["mode"] == "direct"

    async def test_mode_toggle_on_turn_off(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_turn_off()
        await hass.async_block_till_done()
        assert fired[0].data["mode"] == "toggle"

    async def test_timer_none_on_manual_action(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        assert fired[0].data["timer"] is None

    async def test_index_difference_positive_going_forward(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        assert fired[0].data["index_difference"] > 0

    async def test_last_entity_id_in_event(self, hass: HomeAssistant) -> None:
        fired: list = []
        hass.bus.listen(EVENT_CYCLED, fired.append)
        core = _core(hass)
        core._current_index = 0
        await core.async_next()
        await hass.async_block_till_done()
        assert fired[0].data["last_entity_id"] == ENTITY_A


# ---------------------------------------------------------------------------
# Device grouping — all adapters must share one device identifier
# ---------------------------------------------------------------------------


class TestDeviceGrouping:
    def test_core_device_info_has_correct_identifier(self, hass: HomeAssistant) -> None:
        core = _core(hass)
        info = core.device_info
        assert info is not None
        ids = info["identifiers"] if isinstance(info, dict) else info.identifiers
        assert (DOMAIN, "eid") in ids

    def test_select_adapter_has_device_info(self, hass: HomeAssistant) -> None:
        from custom_components.state_cycler.select import StateCyclerSelect

        entry = _entry()
        hass.data.setdefault(DOMAIN, {})
        hass.data[DOMAIN][entry.entry_id] = {}
        adapter = StateCyclerSelect(hass, entry)
        assert adapter.device_info is not None

    def test_switch_adapter_identifier(self, hass: HomeAssistant) -> None:
        from custom_components.state_cycler.switch import StateCyclerSwitch

        adapter = StateCyclerSwitch(hass, _entry())
        assert (DOMAIN, "eid") in adapter.device_info.identifiers

    def test_raw_sensor_identifier(self, hass: HomeAssistant) -> None:
        from custom_components.state_cycler.sensor import StateCyclerRawSensor

        adapter = StateCyclerRawSensor(hass, _entry())
        assert (DOMAIN, "eid") in adapter.device_info.identifiers

    def test_friendly_sensor_identifier(self, hass: HomeAssistant) -> None:
        from custom_components.state_cycler.sensor import StateCyclerFriendlySensor

        adapter = StateCyclerFriendlySensor(hass, _entry())
        assert (DOMAIN, "eid") in adapter.device_info.identifiers

    def test_next_button_identifier(self, hass: HomeAssistant) -> None:
        from custom_components.state_cycler.button import StateCyclerNextButton

        adapter = StateCyclerNextButton(hass, _entry())
        assert (DOMAIN, "eid") in adapter.device_info.identifiers

    def test_prev_button_identifier(self, hass: HomeAssistant) -> None:
        from custom_components.state_cycler.button import StateCyclerPrevButton

        adapter = StateCyclerPrevButton(hass, _entry())
        assert (DOMAIN, "eid") in adapter.device_info.identifiers

    def test_all_adapters_share_same_identifier(self, hass: HomeAssistant) -> None:
        """Every adapter must group under the same HA device as the core."""
        from custom_components.state_cycler.button import StateCyclerNextButton, StateCyclerPrevButton
        from custom_components.state_cycler.select import StateCyclerSelect
        from custom_components.state_cycler.sensor import (
            StateCyclerFriendlySensor,
            StateCyclerRawSensor,
        )
        from custom_components.state_cycler.switch import StateCyclerSwitch

        entry = _entry()
        hass.data.setdefault(DOMAIN, {})
        hass.data[DOMAIN][entry.entry_id] = {}
        expected = (DOMAIN, "eid")

        adapters = [
            StateCyclerSwitch(hass, entry),
            StateCyclerRawSensor(hass, entry),
            StateCyclerFriendlySensor(hass, entry),
            StateCyclerNextButton(hass, entry),
            StateCyclerPrevButton(hass, entry),
            StateCyclerSelect(hass, entry),
        ]
        for adapter in adapters:
            info = adapter.device_info
            assert info is not None, f"{type(adapter).__name__} missing device_info"
            ids = info["identifiers"] if isinstance(info, dict) else info.identifiers
            assert expected in ids, f"{type(adapter).__name__} wrong device identifier"
