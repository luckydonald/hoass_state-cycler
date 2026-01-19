# The query for the AI to work with.

#### General AI development guidelines:
- Create `ai/PROGRESS.md`, and keep it updated when you complete steps.
- You may refer to `ai/refrences` for code examples of other plugins or extra documentation provided for this task.
- When writing code, follow these guidelines:
  - Always prefer the early-return pattern to reduce nesting of `if`s, etc.
  - Similarly, prefer `if …` -> `continue`/`return`/`break` in loops over large nested blocks.
- If the plugin requires a frontend (which you can deduct from the _Plugin requirements_ section below), use Vue, TS, and SCSS for that.
  - Prefer using `<script setup lang="ts">` style single file components.
  - Use Homeassistant frontend components where possible, e.g., `<ha-icon>`, `<ha-card>`, `<ha-button>`, etc.
  - Use proper TypeScript type hinting, importing types from Homeassistant where possible.
- If the plugin requires a backend (which you can deduct from the _Plugin requirements_ section below), use modern Python 3.12+ for that.
  - Do proper type hinting with full type annotations.
  - For type-hinting, import types from Homeassistant where possible for the backend as well.
  - Prefer async programming where possible.
- Write tests for both frontend and backend parts of the plugin.
- Remember to update the `/CHANGELOG.md` and `/README.md` (or possibly additional pre-existing documentation).
- Please put all summaries and such you wanna write for me into the `ai/` folder. However, you don't need to write Markdown summaries, it's kinda redundant with the `PROGRESS.md` file.

Generate me a Homeassistant plugin based on the following description.

#### Plugin requirements:

- The plugin is named "State Cycler".
- It allows a user to add entities (lights, switches, scenes, etc.) to a list and then cycle through them being turned on.
  - Those entities will now be called states.
- The user can configure the order of entities in the list (part of the entity picker UI).
- So the plugin basically turns off the old state/toggle/light, and turns on the next one in the list.
  - for that, it tracks how the entity looked like before turning it off, so that it can restore it when cycling back.
  - When reaching the end of the list, it cycles back to the start, optionally with a "off" state in between. This can be toggled/configured by the user. This setting is exposed in the panel config UI and also via an attribute on the main entity, so it can even be scripted or whatever.
- The following actions are available for a configured State Cycler entity:
  - `next`: cycles to the next state in the list.
  - `prev`: cycles to the previous state in the list.
  - `to`: takes an additional parameter, the index of the state to set (0-based). (out of bounds indices throw an error in the log)
  - `off`: turns off all states. (if the off state is included in the cycle, it cycles to that state)
  - `on`: turns on the last selected (non-off) state, or re-applys the current state if already on. (if the off state is included in the cycle, it cycles to the next state, after the off state)
  - `switch`: toggles between on and off.
  - `cycle`: Basically a combination of `next` and `on`/`off`: if currently off, it turns on the first state, otherwise it cycles to the next one. After a settable interval, the "next" mode changes to "off" mode, so that the next cycle turns it off. This is useful for button presses, where you want to turn on the first state on the first press, click a few times to cycle through, and then by waiting a bit the next press turns it off again.
- The main entity created is of type `state_cycler.cycler`, with attributes:
  - `friendly_name`: name of the entity, default is "State Cycler". Configured in UI. (maybe Home Assistant does this automatically? then skip that!)
  - `state`: either `off` or the `entity_id` of the currently active state — This is the main state of the entity.
  - `state_friendly`: friendly name of the currently active state, or "Off" if off.
  - `index`: index of the currently active state, or -1 if off.
  - `toggle_state`: boolean, if the cycler is currently on (some state active) or off.
  - `include_off_state`: boolean (toggable/writable), whether to include an off state between cycles.
  - `last_state`: the last active state (when cycling), or the state before turning off (`entity_id`), or "off" if it was on the off state. Unavailable on first initialization.
  - `last_index`: the last active index (when cycling), or the index before turning off, or -1 if it was on the off state. Unavailable on first initialization.
  - `timer_interval`: float | None, the interval in seconds for the cycle timer, or None if disabled. Configured in UI.
  - `states`: list of configured states (entities). Configured in UI. Without special "off" state.
- The following events are fired:
  - `state_cycler.cycled` (with attributes:
    - `entity_id: str | "Off"`
    - `index: int`,
    - `direction: "next" | "prev"`,
    - `index_difference: int` (e.g. `+1`, `-1`, `+2`, etc.),
    - `wrapped: bool` (whether the cycle wrapped around),
    - `last_index: int`,
    - `last_entity_id: str | "off"`
    - `timer: float | None` (if the action was caused by the cycle timer, this is the time interval set, otherwise None)
    - `mode: "direct" | "cycle" | "toggle" | "timer"` (weather this was a index based action (prev/next/to), via the cycle action, via toggle on/off, or via the cycle timer))
    - `command: "next" | "prev" | "to" | "cycle" | "on" | "off" | "switch"` (the action that caused the event)
  - `state_cycler.initialized` (fired when the entity is loaded/reloaded (HA launch, install, etc.), with attribute `states: list[str]`, `index: int`, `entity_id: str | "Off"`)
  - `state_cycler.cycle_timeout` (fired when the cycle timer times out, with attribute `entity_id: str | "Off"` and `index: int`)
- The user can create multiple State Cycler entities, each with their own list of states.
- The `cycle_state` exposes:
  - a "toggle" button in the UI for "on/off" (like a regular switch - calls `switch` action)
  - a "next" button (the `next` action) (like the ident button on a light), so that the user can manually cycle to the next state.
  - a "cycle" button (the `cycle` action)
- The user can also configure an optional timer interval, so that the cycling happens automatically every x seconds minutes.

———

Create the vue frontend in the frontend/ folder.
Update the `README.md`.

———

Make sure it is showing up as integration in Home Assistant, with proper configuration options in the UI.
we should be able to create multiple of these cyclers? That's what I would do with the add integration button, add a new cycler, where I can then add entities

———
We’ll implement a hybrid architecture: a single authoritative custom entity domain `state_cycler.<id>` (the core) will own all behavior—timers, saved/restored state, events and service handlers—while lightweight native HA adapter entities (e.g., `select.state_cycler_<id>` for enum-like state selection, `switch.state_cycler_<id>` for on/off, optional button/sensor adapters for next/prev and information) mirror and mutate that core state. Adapters never write state directly; they send user actions to the core, which validates and applies changes, drives the underlying devices, then notifies adapters to update their UI state. We’ll use per-cycler locks to prevent feedback loops and race conditions, provide stable unique_ids for smooth migrations, and expose the usual services/events so automations and the UI work natively while preserving a clear, single source of truth.
For that you don't need any old-entity-migration code, just assume a new install.
- Implement friendly-label mapping for the Select adapter so the user sees friendly names in the dropdown while the core receives machine ids.
