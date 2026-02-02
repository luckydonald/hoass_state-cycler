import {
  createApp,
  h,
} from 'vue';

import StateCyclerCard from './StateCyclerCard.vue';

import type { App, ComponentPublicInstance } from 'vue';

import type {
  CardConfig,
  HomeAssistant,
  MountedWrapperExtras,
  Wrapper,
} from './types';

interface StateCyclerCardConfig extends CardConfig {
  type?: string;
  // UI/editor related optional properties
  title?: string;
  entity?: string;
  clock_display?: string;
  alarm_list_mode?: 'days' | 'count';
  alarm_list_count?: number;
  alarm_list_days?: number;
  show_clock?: boolean;
  show_quick_alarm?: boolean;
  show_alarm_list?: boolean;
  show_add_section?: string;
}

interface AppData {
  hass: HomeAssistant | null;
  config: StateCyclerCardConfig;
}

class StateCyclerCardElement extends HTMLElement {
  private _config: StateCyclerCardConfig = {};

  private _hass: HomeAssistant | null = null;

  private _app: App | null = null;

  private _root: HTMLDivElement | null = null;

  public set hass(hass: HomeAssistant) {
    this._hass = hass;
    if (this._app?._instance?.proxy) {
      const proxy = this._app._instance.proxy as ComponentPublicInstance & AppData;
      proxy.hass = hass;
    }
  }

  public setConfig(config: StateCyclerCardConfig): void {
    this._config = config;
    if (this._app?._instance?.proxy) {
      const proxy = this._app._instance.proxy as ComponentPublicInstance & AppData;
      proxy.config = config;
    }
  }

  public connectedCallback(): void {
    if (!this._root) {
      this._root = document.createElement('div');
      this.appendChild(this._root);
    }

    const initialHass = this._hass;
    const initialConfig = this._config;

    this._app = createApp({
      data(): AppData {
        return {
          hass: initialHass,
          config: initialConfig,
        };
      },
      render() {
        const data = this as unknown as AppData;
        return h(StateCyclerCard, {
          hass: data.hass,
          config: data.config,
        });
      },
    });

    this._app.mount(this._root);
  }

  public disconnectedCallback(): void {
    if (this._app) {
      this._app.unmount();
      this._app = null;
    }
  }

  public getCardSize(): number {
    return 4;
  }

  public static getConfigElement(): HTMLElement {
    // Create a wrapper element and mount the Vue editor into it.
    // Define 'hass' and 'setConfig' on the element so Home Assistant can safely set properties.
    const wrapper: Wrapper<StateCyclerCardConfig> = document.createElement('div');

    // Mount the Vue editor into the wrapper. Keep a reference to the VM proxy so we can update props.
    // eslint-disable-next-line @typescript-eslint/no-use-before-define
    const app = createApp(StateCyclerCardEditor, {
      hass: null,
      config: {},
      onConfigChanged: (cfg: StateCyclerCardConfig) => {
        // When the editor notifies of config changes, dispatch an event from the wrapper so HA picks it up
        const event = new CustomEvent('config-changed', {
          detail: { config: cfg },
          bubbles: true,
          composed: true,
        });
        wrapper.dispatchEvent(event);
      },
    });

    // noinspection UnnecessaryLocalVariableJS
    const vmOrigForTyping = app.mount(wrapper);
    const vm = vmOrigForTyping as typeof vmOrigForTyping & MountedWrapperExtras<StateCyclerCardConfig>;

    // Define a 'hass' property so HA can set it (and we forward it to the Vue component proxy)
    Object.defineProperty(wrapper, 'hass', {
      configurable: true,
      enumerable: true,
      set(hass: HomeAssistant) {
        try {
          if (vm) vm.hass = hass;
        } catch {
          // ignore errors setting on vm
        }
      },
      get(): HomeAssistant | null {
        return vm?.hass ?? null;
      },
    });

    // Provide a setConfig method which HA uses to initialize the editor
    wrapper.setConfig = (config: StateCyclerCardConfig) => {
      try {
        if (vm) vm.config = config;
      } catch {
        // ignore
      }
    };

    return wrapper;
  }

  public static getStubConfig(): StateCyclerCardConfig {
    return {
      type: 'custom:state-cycler-card',
      title: 'State Cycler',
    };
  }
}

class StateCyclerCardEditor extends HTMLElement {
  private _config: StateCyclerCardConfig = {};

  private _hass: HomeAssistant | null = null;

  public set hass(hass: HomeAssistant) {
    this._hass = hass;
    this._render();
  }

  public setConfig(config: StateCyclerCardConfig): void {
    this._config = config;
    this._render();
  }

  private _render(): void {
    if (!this._hass) return;
    this._renderManual();
  }

  private _renderManual(): void {
    this.innerHTML = '';

    const wrapper = document.createElement('div');
    wrapper.style.padding = '16px';
    wrapper.style.display = 'flex';
    wrapper.style.flexDirection = 'column';
    wrapper.style.gap = '16px';

    // Title input
    wrapper.appendChild(this._createTextInput(
      'title',
      'Card Title',
      this._config.title ?? 'State Cycler',
    ));

    // Entity picker (for single alarm view)
    wrapper.appendChild(this._createEntityPicker());

    // Clock display select
    wrapper.appendChild(this._createSelect(
      'clock_display',
      'Clock Display',
      this._config.clock_display ?? 'analog',
      [
        {
          value: 'analog',
          label: 'Analog',
        },
        {
          value: '24h',
          label: 'Digital (24h)',
        },
        {
          value: '12h',
          label: 'Digital (12h)',
        },
        {
          value: 'none',
          label: 'None',
        },
      ],
    ));

    // Alarm list mode select
    wrapper.appendChild(this._createSelect(
      'alarm_list_mode',
      'Alarm List Mode',
      this._config.alarm_list_mode ?? 'days',
      [
        {
          value: 'days',
          label: 'Show alarms for X days',
        },
        {
          value: 'count',
          label: 'Show X alarms',
        },
      ],
    ));

    // Alarm list days/count input
    if (this._config.alarm_list_mode === 'count') {
      wrapper.appendChild(this._createNumberInput(
        'alarm_list_count',
        'Number of Alarms to Show',
        this._config.alarm_list_count ?? 10,
        1,
        100,
      ));
    } else {
      wrapper.appendChild(this._createNumberInput(
        'alarm_list_days',
        'Days to Show',
        this._config.alarm_list_days ?? 7,
        1,
        365,
      ));
    }

    // Section visibility toggles
    const sectionHeader = document.createElement('div');
    sectionHeader.style.fontWeight = '500';
    sectionHeader.style.marginTop = '8px';
    sectionHeader.textContent = 'Section Visibility';
    wrapper.appendChild(sectionHeader);

    wrapper.appendChild(this._createToggle(
      'show_clock',
      'Show Clock Section',
      this._config.show_clock !== false,
    ));

    wrapper.appendChild(this._createToggle(
      'show_quick_alarm',
      'Show Quick Alarm Section',
      this._config.show_quick_alarm !== false,
    ));

    wrapper.appendChild(this._createToggle(
      'show_alarm_list',
      'Show Alarm List Section',
      this._config.show_alarm_list !== false,
    ));

    // Add section mode
    wrapper.appendChild(this._createSelect(
      'show_add_section',
      'Add Alarm Section',
      this._config.show_add_section ?? 'auto',
      [
        {
          value: 'auto',
          label: 'Auto (show when Add clicked)',
        },
        {
          value: 'on',
          label: 'Always show',
        },
        {
          value: 'off',
          label: 'Never show (dialog only)',
        },
      ],
    ));

    // Help text
    const helpText = document.createElement('div');
    helpText.style.color = 'var(--secondary-text-color)';
    helpText.style.fontSize = '12px';
    helpText.style.marginTop = '8px';
    helpText.innerHTML = /* html */ `
      <p style="margin: 0 0 8px 0;"><strong>List View (default):</strong> Leave entity empty to show all alarms.</p>
      <p style="margin: 0;"><strong>Single Alarm View:</strong> Select a specific alarm entity to show details for one alarm.</p>
    `;
    wrapper.appendChild(helpText);

    this.appendChild(wrapper);
  }

  private _createTextInput(
    name: string,
    label: string,
    value: string,
  ): HTMLDivElement {
    const row = document.createElement('div');

    const labelEl = document.createElement('label');
    labelEl.textContent = label;
    labelEl.style.display = 'block';
    labelEl.style.marginBottom = '4px';
    labelEl.style.fontWeight = '500';
    labelEl.style.color = 'var(--primary-text-color)';

    const input = document.createElement('ha-textfield') as HTMLInputElement;
    input.setAttribute('label', label);
    input.setAttribute('value', value);
    input.style.width = '100%';
    input.addEventListener('input', (e: Event) => {
      const target = e.target as HTMLInputElement;
      this._updateConfig({ [name]: target.value });
    });

    row.appendChild(labelEl);
    row.appendChild(input);
    return row;
  }

  private _createNumberInput(
    name: string,
    label: string,
    value: number,
    min: number,
    max: number,
  ): HTMLDivElement {
    const row = document.createElement('div');

    const labelEl = document.createElement('label');
    labelEl.textContent = label;
    labelEl.style.display = 'block';
    labelEl.style.marginBottom = '4px';
    labelEl.style.fontWeight = '500';
    labelEl.style.color = 'var(--primary-text-color)';

    const input = document.createElement('ha-textfield') as HTMLInputElement;
    input.setAttribute('type', 'number');
    input.setAttribute('label', label);
    input.setAttribute('value', String(value));
    input.setAttribute('min', String(min));
    input.setAttribute('max', String(max));
    input.style.width = '100%';
    input.addEventListener('input', (e: Event) => {
      const target = e.target as HTMLInputElement;
      this._updateConfig({ [name]: Number(target.value) });
    });

    row.appendChild(labelEl);
    row.appendChild(input);
    return row;
  }

  private _createSelect(
    name: string,
    label: string,
    value: string,
    options: {
      value: string;
      label: string;
    }[],
  ): HTMLDivElement {
    const row = document.createElement('div');

    const labelEl = document.createElement('label');
    labelEl.textContent = label;
    labelEl.style.display = 'block';
    labelEl.style.marginBottom = '4px';
    labelEl.style.fontWeight = '500';
    labelEl.style.color = 'var(--primary-text-color)';

    const select = document.createElement('ha-select') as HTMLSelectElement;
    select.setAttribute('label', label);
    select.style.width = '100%';

    options.forEach((opt) => {
      const optionEl = document.createElement('mwc-list-item');
      optionEl.setAttribute('value', opt.value);
      optionEl.textContent = opt.label;
      if (opt.value === value) {
        optionEl.setAttribute('selected', '');
      }
      select.appendChild(optionEl);
    });

    select.value = value;

    select.addEventListener('selected', (e: Event) => {
      const target = e.target as HTMLSelectElement;
      this._updateConfig({ [name]: target.value });
    });

    row.appendChild(labelEl);
    row.appendChild(select);
    return row;
  }

  private _createToggle(
    name: string,
    label: string,
    checked: boolean,
  ): HTMLDivElement {
    const row = document.createElement('div');
    row.style.display = 'flex';
    row.style.alignItems = 'center';
    row.style.justifyContent = 'space-between';

    const labelEl = document.createElement('span');
    labelEl.textContent = label;
    labelEl.style.color = 'var(--primary-text-color)';

    const toggle = document.createElement('ha-switch') as HTMLInputElement;
    if (checked) {
      toggle.setAttribute('checked', '');
    }
    toggle.addEventListener('change', (e: Event) => {
      const target = e.target as HTMLInputElement;
      this._updateConfig({ [name]: target.checked });
    });

    row.appendChild(labelEl);
    row.appendChild(toggle);
    return row;
  }

  private _createEntityPicker(): HTMLDivElement {
    const row = document.createElement('div');

    const labelEl = document.createElement('label');
    labelEl.textContent = 'Entity (optional - for single alarm view)';
    labelEl.style.display = 'block';
    labelEl.style.marginBottom = '4px';
    labelEl.style.fontWeight = '500';
    labelEl.style.color = 'var(--primary-text-color)';

    const entityPicker = document.createElement('ha-entity-picker');
    entityPicker.setAttribute('allow-custom-entity', '');
    entityPicker.setAttribute('label', 'Entity (optional)');
    if (this._config.entity) {
      entityPicker.setAttribute('value', this._config.entity);
    }
    entityPicker.hass = this._hass;
    entityPicker.includeDomains = [
      'sensor',
    ];
    entityPicker.style.width = '100%';
    entityPicker.addEventListener('value-changed', (e: Event) => {
      const customEvent = e as CustomEvent;
      this._updateConfig({ entity: customEvent.detail.value ?? '' });
    });

    row.appendChild(labelEl);
    row.appendChild(entityPicker);
    return row;
  }

  private _updateConfig(update: Partial<StateCyclerCardConfig>): void {
    this._config = {
      ...this._config,
      ...update,
    };
    this._fireConfigChanged();
  }

  private _fireConfigChanged(): void {
    const event = new CustomEvent('config-changed', {
      detail: { config: this._config },
      bubbles: true,
      composed: true,
    });
    this.dispatchEvent(event);
  }
}

// Register custom elements
customElements.define('state-cycler-card', StateCyclerCardElement);
customElements.define('state-cycler-card-editor', StateCyclerCardEditor);

// Register with Home Assistant's custom card registry
window.customCards = window.customCards ?? [];
window.customCards.push({
  type: 'custom:state-cycler-card',
  name: 'State Cycler Card',
  description: 'A plugin template card for Home Assistant',
  preview: true,
});

// eslint-disable-next-line no-console
console.info(
  '%c STATE-CYCLER-CARD %c dev',
  'color: white; background: #3498db; font-weight: bold;',
  'color: #3498db; background: white; font-weight: bold;',
);
