# Memory Index

This directory holds persistent memory files for the State Cycler project.

## Project files

| File | Name | Description |
|------|------|-------------|
| [project_cycle_timeout_bug.md](project_cycle_timeout_bug.md) | cycle-timeout-off bug | Known implementation gap where `async_cycle` after a cycle timeout does not turn off as per spec |
| [project_test_toggle_logic.md](project_test_toggle_logic.md) | test_toggle_logic test suite | New unit test file for state toggling logic; one test intentionally fails due to cycle-timeout spec gap |
