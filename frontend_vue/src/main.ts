import { type App, type ComponentPublicInstance, createApp, h } from 'vue';
import PluginTemplateCard from './PluginTemplateCard.vue';
import type { CardConfig, HomeAssistant } from './types';

interface PluginTemplateCardConfig extends CardConfig {
  type?: string;
}

interface AppData {
  hass: HomeAssistant | null;
  config: PluginTemplateCardConfig;
}

class PluginTemplateCardElement extends HTMLElement {
  private _config: PluginTemplateCardConfig = {};
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

  public setConfig(config: PluginTemplateCardConfig): void {
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
        return h(PluginTemplateCard, {
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

  public static getConfigElement(): PluginTemplateCardEditor {
    return document.createElement('plugin-template-card-editor') as PluginTemplateCardEditor;
  }

  public static getStubConfig(): PluginTemplateCardConfig {
    return {
      type: 'custom:plugin-template-card',
      title: 'Plugin Template',
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
      this._config.title ?? 'Plugin Template',
    ));

    // Entity picker (optional)
    wrapper.appendChild(this._createEntityPicker());


    this.appendChild(wrapper);
  }

    // Entity picker (optional)
    name: string,
    label: string,
    this.appendChild(wrapper);
  }
    options.forEach((opt) => {
      const optionEl = document.createElement('mwc-list-item');
    // Entity picker (optional)
      optionEl.textContent = opt.label;
      if (opt.value === value) {
    this.appendChild(wrapper);
  }
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
customElements.define('plugin-template-card', PluginTemplateCardElement);
customElements.define('plugin-template-card-editor', PluginTemplateCardEditor);

// Register with Home Assistant's custom card registry
declare global {
  interface Window {
    customCards: Array<{
      type: string;
      name: string;
      description: string;
      preview?: boolean;
    }>;
  }
}

window.customCards = window.customCards || [];
window.customCards.push({
  type: 'plugin-template-card',
  name: 'Plugin Template Card',
  description: 'A template card for Home Assistant',
  preview: true,
});

console.info(
  '%c PLUGIN-TEMPLATE-CARD %c 0.0.0-dev0 ',
  'color: white; background: #3498db; font-weight: bold;',
  'color: #3498db; background: white; font-weight: bold;',
);
