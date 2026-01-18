# State Cycler for Home Assistant

> A Home Assistant integration that allows cycling through a list of entities (lights, switches, scenes) with manual and automatic controls, including a custom Lovelace card for easy interaction.


[![hacs_badge](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![GitHub Release](https://img.shields.io/github/release/luckydonald/hoass_state-cycler.svg)](https://github.com/luckydonald/hoass_state-cycler/releases)
[![CI](https://github.com/luckydonald/hoass_state-cycler/actions/workflows/ci.yml/badge.svg)](https://github.com/luckydonald/hoass_state-cycler/actions/workflows/ci.yml)

[![License](https://img.shields.io/github/license/luckydonald/hoass_state-cycler.svg)](LICENSE)
![AI Usage: marked](https://img.shields.io/badge/AI-Usage%20marked-brightgreen.svg)

![Vue 3.5](https://img.shields.io/badge/Vue-3.5-4FC08D.svg)
![Typescript 5.6](https://img.shields.io/badge/TypeScript-5.6-3178C6.svg)
![Python 3.12](https://img.shields.io/badge/Python-3.12+-3776AB.svg)

## Features

- **Entity Cycling**: Create State Cycler entities that manage lists of lights, switches, scenes, and other entities
- **Manual Control**: Cycle through states with next/previous buttons or jump to specific states
- **Automatic Cycling**: Optional timer for automatic state transitions
- **Smart Toggle**: Toggle between on/off states, remembering previous settings
- **Cycle Mode**: Special cycling logic for button presses with timeout behavior
- **State Preservation**: Remembers and restores entity states (brightness, color, etc.) when cycling back
- **Custom Lovelace Card**: Beautiful card for Lovelace dashboards with state display and controls
- **Events & Automation**: Fires events for all state changes to enable powerful automations
- **Multiple Entities**: Create multiple independent State Cycler entities
- **Configuration UI**: Easy setup through Home Assistant's integration configuration flow

## Installation

### HACS (Recommended)

[![Open your Home Assistant instance and open a repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository/?owner=luckydonald&repository=hoass_state-cycler&category=integration)

Or manually:

1. Open HACS in Home Assistant
2. Click on "Integrations"
3. Click the three dots in the top right corner
4. Select "Custom repositories"
5. Add `https://github.com/luckydonald/hoass_state-cycler` and select "Integration" as the category
6. Click "Install"
7. Restart Home Assistant

### Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/luckydonald/hoass_state-cycler/releases)
2. Copy the `custom_components/state_cycler` folder to your `custom_components` directory
3. Copy the built frontend file `state-cycler-card.js` to your `www` folder (or serve it via your web server)
4. Restart Home Assistant

## Configuration

After installation, add the State Cycler integration through the Home Assistant UI:

1. Go to **Settings** → **Devices & Services** → **Add Integration**
2. Search for "State Cycler" and select it
3. Configure your State Cycler entity:
   - **Name**: Friendly name for the entity
   - **States**: List of entity IDs to cycle through (lights, switches, scenes, etc.)
   - **Include Off State**: Whether to include an "off" state in the cycle
   - **Timer Interval**: Optional automatic cycling interval in seconds

## Usage

### Lovelace Card

Add the State Cycler card to your Lovelace dashboard:

```yaml
type: custom:state-cycler-card
entity: state_cycler.your_cycler_name
title: My State Cycler  # Optional
```

The card displays:
- Current active state with friendly name and index
- Toggle button (on/off)
- Next button for manual cycling
- Cycle button with smart timeout logic
- List of all configured states with active highlighting

### Services

The State Cycler provides several services you can call:

- `state_cycler.next`: Cycle to next state
- `state_cycler.prev`: Cycle to previous state
- `state_cycler.to`: Jump to specific index (provide `index` parameter)
- `state_cycler.off`: Turn off all states
- `state_cycler.on`: Turn on last active state
- `state_cycler.switch`: Toggle on/off
- `state_cycler.cycle`: Smart cycling with timeout

Example automation:

```yaml
automation:
  - alias: "Cycle lights on button press"
    trigger:
      platform: state
      entity_id: binary_sensor.button
      to: "on"
    action:
      service: state_cycler.cycle
      target:
        entity_id: state_cycler.living_room_lights
```

### Events

The integration fires events for automation:

- `state_cycler.cycled`: Fired on every state change with details about the transition
- `state_cycler.initialized`: Fired when entity is loaded/reloaded
- `state_cycler.cycle_timeout`: Fired when cycle mode times out

## Entity Attributes

The State Cycler entity exposes these attributes:

- `state`: Current state (`off` or entity_id)
- `state_friendly`: Friendly name of current state
- `index`: Current index (-1 if off)
- `toggle_state`: Boolean on/off status
- `include_off_state`: Whether off state is included in cycle
- `last_state`: Previously active state
- `last_index`: Previously active index
- `timer_interval`: Auto-cycle interval (null if disabled)
- `states`: List of configured entity IDs

## Examples

### Basic Light Cycling

Create a State Cycler for bedroom lights:

```yaml
# Configuration
name: "Bedroom Lights"
states:
  - light.bedroom_main
  - light.bedroom_lamp
  - scene.bedroom_cozy
include_off_state: true
timer_interval: null
```

### Automatic Scene Rotation

Cycle through living room scenes every 30 minutes:

```yaml
name: "Living Room Scenes"
states:
  - scene.living_bright
  - scene.living_movie
  - scene.living_dinner
include_off_state: false
timer_interval: 1800  # 30 minutes
```

### Button-Controlled Cycling

Use with a physical button for manual control:

```yaml
automation:
  - alias: "Button cycles kitchen lights"
    trigger:
      platform: event
      event_type: state_cycler.cycled
      event_data:
        entity_id: state_cycler.kitchen_lights
    condition:
      condition: template
      value_template: "{{ trigger.event.data.command == 'cycle' }}"
    action:
      - service: notify.mobile_app
        data:
          message: "Kitchen lights cycled to {{ trigger.event.data.state_friendly }}"
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<!-- footer -->
# Repository Information
## Tags
- <kbd>state-cycler</kbd>
- <kbd>home-assistant</kbd>
- <kbd>hacs</kbd>
- <kbd>hacs-integration</kbd>
- <kbd>homeassistant-integration</kbd>
- <kbd>home-assistant-integration</kbd>
- <kbd>homeassistant-custom-integration</kbd>
- <kbd>custom-card</kbd>
- <kbd>homeassistant-custom-card</kbd>
- <kbd>lovelace-card</kbd>
- <kbd>custom-component</kbd>
- <kbd>homeassistant-custom-component</kbd>
- <kbd>home-assistant-custom-component-hacs</kbd>
- <kbd>luckydonald</kbd>
