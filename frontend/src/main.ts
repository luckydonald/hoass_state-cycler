import { type App, type ComponentPublicInstance, createApp, h } from 'vue';
import StateCyclerCard from './StateCyclerCard.vue';
import type { CardConfig, HomeAssistant } from './types';

interface StateCyclerCardConfig extends CardConfig {
  type?: string;
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

  public static getStubConfig(): StateCyclerCardConfig {
    return {
      type: 'custom:state-cycler-card',
      title: 'State Cycler',
    };
  }
}

// Register custom element
customElements.define('state-cycler-card', StateCyclerCardElement);

// Register with Home Assistant's custom card registry
window.customCards = window.customCards || [];
window.customCards.push({
  type: 'state-cycler-card',
  name: 'State Cycler Card',
  description: 'A template card for Home Assistant',
  preview: true,
});

console.info(
  '%c STATE-CYCLER-CARD %c 0.0.0-dev0 ',
  'color: white; background: #3498db; font-weight: bold;',
  'color: #3498db; background: white; font-weight: bold;',
);
