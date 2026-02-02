/// <reference types="vite/client" />

// Exported element interfaces for Home Assistant web components
import pkg from '../package.json';

export interface HACardElement extends HTMLElement {
  header?: string;
}

export interface HAIconElement extends HTMLElement {
  icon: string;
}

export interface HAIconButtonElement extends HTMLElement {}

export interface HASwitchElement extends HTMLInputElement {
  // HTMLInputElement already has `checked`, but keep as explicit contract
  checked: boolean;
}

export interface HADialogElement extends HTMLElement {
  open: boolean;
  heading: string;
}

export interface HATextfieldElement extends HTMLInputElement {
  label: string;
  value: string;
}

export interface HASelectElement extends HTMLSelectElement {
  label: string;
  value: string;
}

export interface HAFabElement extends HTMLElement {
  extended: boolean;
  label: string;
}

export interface HAListElement extends HTMLElement {}

export interface HAListItemElement extends HTMLElement {
  graphic: string;
  hasMeta: boolean;
}

export interface HAExpansionPanelElement extends HTMLElement {
  outlined: boolean;
  expanded: boolean;
  header: string;
}

export interface HAFormfieldElement extends HTMLElement {
  label: string;
}

export interface HAEntityPickerElement extends HTMLElement {
  hass: unknown;
  value: string;
  label: string;
  includeDomains: string[];
}

export interface HAButtonElement extends HTMLElement {
  raised: boolean;
  outlined: boolean;
  dense: boolean;
  slot: string;
  dialogAction: string;
  // Optional version field embedded from frontend/package.json
  version?: string;
}

declare module '*.vue' {
  import type { DefineComponent } from 'vue';

  const component: DefineComponent<object, object, unknown>;
  export default component;
}

// Augment HTMLElementTagNameMap for Home Assistant custom elements
declare global {
  interface HTMLElementTagNameMap {
    'ha-card': HACardElement;
    'ha-icon': HAIconElement;
    'ha-icon-button': HAIconButtonElement;
    'ha-switch': HASwitchElement;
    'ha-dialog': HADialogElement;
    'ha-textfield': HATextfieldElement;
    'ha-select': HASelectElement;
    'ha-fab': HAFabElement;
    'ha-list': HAListElement;
    'ha-list-item': HAListItemElement;
    'ha-expansion-panel': HAExpansionPanelElement;
    'ha-formfield': HAFormfieldElement;
    'ha-entity-picker': HAEntityPickerElement;
    'ha-button': HAButtonElement;
  }

  interface Window {
    customCards?: {
      type: string;
      name: string;
      description: string;
      preview?: boolean;
      version?: string;
    }[];
  }
}

// Declare Home Assistant custom elements as Vue global components
declare module 'vue' {
  export interface GlobalComponents {
    'ha-card': HACardElement;
    'ha-icon': HAIconElement;
    'ha-icon-button': HAIconButtonElement;
    'ha-switch': HASwitchElement;
    'ha-dialog': HADialogElement;
    'ha-textfield': HATextfieldElement;
    'ha-select': HASelectElement;
    'ha-fab': HAFabElement;
    'ha-list': HAListElement;
    'ha-list-item': HAListItemElement;
    'ha-expansion-panel': HAExpansionPanelElement;
    'ha-formfield': HAFormfieldElement;
    'ha-entity-picker': HAEntityPickerElement;
    'ha-button': HAButtonElement;
  }
}

// Export the element types for consumers (allow importing e.g. { HASelectElement })
export type {
  HAButtonElement,
  HACardElement,
  HADialogElement,
  HAEntityPickerElement,
  HAExpansionPanelElement,
  HAFabElement,
  HAFormfieldElement,
  HAIconButtonElement,
  HAIconElement,
  HAListElement,
  HAListItemElement,
  HASelectElement,
  HASwitchElement,
  HATextfieldElement,
};

export {};
