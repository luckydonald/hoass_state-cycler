- [x] Implement Vue frontend card with state display and action buttons
- [x] Update types.ts with StateCycler entity interfaces
- [x] Create comprehensive tests for the frontend card
- [x] Update README.md with complete documentation, features, installation, configuration, usage examples, and API details
- [x] Fix hassfest validation errors (quoted YAML boolean keys in services.yaml, added missing _get_saved_state method)
- [x] Ensure integration shows up in Home Assistant with proper configuration UI (config flow with entity list, include_off_state, timer_interval options)
- [x] Fix manifest/platform mismatch and forwarded sensor platform setup (manifest.json, const.py, __init__.py, sensor.py)
- [ ] Test in actual Home Assistant instance
- [ ] Test with various entity types (lights, switches, scenes)
- [ ] Test state restoration after HA restart
- [ ] Test timer functionality
- [ ] Test with multiple State Cycler entities
- [ ] Test frontend card integration
- [x] Add comprehensive Home Assistant integration tests in `tests/test_integration_full.py`
- [ ] Run tests in CI (local `make test-py` to validate)

### Enhancements (Future)
- [ ] Drag-and-drop reordering in frontend
- [ ] Entity picker with autocomplete
- [ ] Config entry updates from frontend (requires HA API calls)
- [ ] Visual state preview in frontend
- [ ] Transition effects/animations
- [ ] Import/export configurations

## Known Limitations

1. **Config Editing**: Frontend edit mode shows local state only - actual persistence requires calling HA config entry update API (not yet implemented)
2. **Entity Picker**: Uses text input - could be enhanced with autocomplete from available entities
3. **Reordering**: Uses up/down buttons - drag-and-drop would be more intuitive
4. **IDE Errors**: Expected errors in IDE (missing homeassistant module, Vue template parsing) - files will work correctly in HA

## Architecture Notes

- **Platform**: Uses standard HA platform `sensor` (manifest & PLATFORMS updated) and forwards to the main implementation in `state_cycler.py` via `sensor.py`
- **Entity State**: Main state is the entity_id of active state or "off"
- **State Preservation**: Saves entity attributes (brightness, color, etc.) in memory for restoration
- **Config Storage**: All configuration in config entry data
- **State Restoration**: Uses `RestoreEntity` to resume after HA restart
- **Async Throughout**: Proper async/await for non-blocking operation

## Files Modified

- custom_components/state_cycler/manifest.json  (platforms -> ["sensor"]) 
- custom_components/state_cycler/const.py      (PLATFORMS -> ["sensor"]) 
- custom_components/state_cycler/__init__.py   (PLATFORMS -> ["sensor"]) 
- custom_components/state_cycler/sensor.py     (forwards platform setup to state_cycler.async_setup_entry)

## Next Steps

1. Run unit tests (`pytest`) and fix any failures
2. Validate types/lint (`mypy`, `ruff`) and fix warnings
3. Install into a Home Assistant instance (or use local dev container) and verify the integration appears in Settings → Devices & Services → Add Integration
4. If everything works, publish a new release and update HACS listing
