---
name: cycle-timeout-off bug
description: Known implementation gap where async_cycle after a cycle timeout does not turn off as per spec
type: project
---

After `_cycle_timeout()` fires (`_cycle_mode_active = False`), the spec says the next `async_cycle` call should turn off the cycler. The current `async_cycle` implementation instead restarts cycle-forward mode (`else` branch sets `_cycle_mode_active = True` and calls `async_next`).

**Why:** The `async_cycle` method has no way to distinguish "timed out, pending off" from "freshly stopped". A `_pending_cycle_off` flag (set in `_cycle_timeout`, cleared in `async_cycle`) would fix this.

**How to apply:** When someone asks to implement or fix the `cycle` action timeout behaviour, add a `_pending_cycle_off: bool = False` field to `StateCyclerEntity.__init__`, set it `True` in `_cycle_timeout`, and check it first in `async_cycle` (turn off and clear the flag when set).

The test `tests/test_toggle_logic.py::TestCycle::test_after_timeout_next_cycle_turns_off` will remain failing until this is fixed.
