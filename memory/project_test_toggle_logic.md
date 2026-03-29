---
name: test_toggle_logic test suite
description: New unit test file for state toggling logic; one test intentionally fails due to cycle-timeout spec gap
type: project
---

`tests/test_toggle_logic.py` was written to cover all actions from `ai/query.md`: next, prev, to, off, on, switch, cycle (including cycle-mode and timeout), state attributes, cycled event fields, and device-grouping.

74 of 75 tests pass. The one intentional failing test is `TestCycle::test_after_timeout_next_cycle_turns_off` — it documents the cycle-timeout spec gap above.

**How to apply:** When adding new toggle logic or fixing the cycle-timeout bug, run `uv run pytest tests/test_toggle_logic.py -q` to check regressions.
