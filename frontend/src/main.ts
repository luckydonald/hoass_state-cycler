import {
  createApp,
  h,
} from 'vue';
import type {
  App,
  ComponentPublicInstance,
} from 'vue';

import StateCyclerCard from './StateCyclerCard.vue';

import type {
  CardConfig,
  HomeAssistant,
  MountedWrapperExtras,
  Wrapper,
} from './types';

interface StateCyclerCardConfig extends CardConfig {
  type?: string;
  // UI/editor related optional properties
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

  /* public static getConfigElement(): HTMLElement {
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
  } */

  public static getStubConfig(): StateCyclerCardConfig {
    return {
      type: 'custom:state-cycler-card',
      title: 'State Cycler',
    };
  }
}

// Register custom elements
customElements.define('state-cycler-card', StateCyclerCardElement);
// customElements.define('state-cycler-card-editor', StateCyclerCardEditor);

// Register with Home Assistant's custom card registry
window.customCards = window.customCards ?? [];
window.customCards.push({
  type: 'custom:state-cycler-card',
  name: 'State Cycler Card',
  description: 'A template card for Home Assistant',
  preview: true,
});

// eslint-disable-next-line no-console
console.info(
  '%c STATE-CYCLER-CARD %c 0.0.0-dev0 ',
  'color: white; background: #3498db; font-weight: bold;',
  'color: #3498db; background: white; font-weight: bold;',
);
