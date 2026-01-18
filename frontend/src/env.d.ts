/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue';
  const component: DefineComponent<object, object, unknown>;
  export default component;
}

// Augment HTMLElementTagNameMap for Home Assistant custom elements
declare global {
  interface HTMLElementTagNameMap {
    'ha-card': HTMLElement & {
      header?: string;
    };
    'ha-icon': HTMLElement & {
      icon: string;
    };
    'ha-icon-button': HTMLElement;
    'ha-switch': HTMLInputElement & {
      checked: boolean;
    };
    'ha-dialog': HTMLElement & {
      open: boolean;
      heading: string;
    };
    'ha-textfield': HTMLInputElement & {
      label: string;
      value: string;
    };
    'ha-select': HTMLSelectElement & {
      label: string;
      value: string;
    };
    'ha-fab': HTMLElement & {
      extended: boolean;
      label: string;
    };
    'ha-list': HTMLElement;
    'ha-list-item': HTMLElement & {
      graphic: string;
      hasMeta: boolean;
    };
    'ha-expansion-panel': HTMLElement & {
      outlined: boolean;
      expanded: boolean;
      header: string;
    };
    'ha-formfield': HTMLElement & {
      label: string;
    };
    'ha-entity-picker': HTMLElement & {
      hass: unknown;
      value: string;
      label: string;
      includeDomains: string[];
    };
    'mwc-button': HTMLElement & {
      raised: boolean;
      outlined: boolean;
      dense: boolean;
      slot: string;
      dialogAction: string;
    };
    'mwc-list-item': HTMLElement & {
      value: string;
      selected: boolean;
    };
  }

  interface Window {
    customCards?: Array<{
      type: string;
      name: string;
      description: string;
      preview?: boolean;
    }>;
  }
}

// Declare Home Assistant custom elements as Vue global components
declare module 'vue' {
  export interface GlobalComponents {
    'ha-card': HTMLElement;
    'ha-icon': HTMLElement;
    'ha-icon-button': HTMLElement;
    'ha-switch': HTMLInputElement;
    'ha-dialog': HTMLElement;
    'ha-textfield': HTMLInputElement;
    'ha-select': HTMLSelectElement;
    'ha-fab': HTMLElement;
    'ha-list': HTMLElement;
    'ha-list-item': HTMLElement;
    'ha-expansion-panel': HTMLElement;
    'ha-formfield': HTMLElement;
    'ha-entity-picker': HTMLElement;
    'mwc-button': HTMLElement;
    'mwc-list-item': HTMLElement;
  }
}

export {};
