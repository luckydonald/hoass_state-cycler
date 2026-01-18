// Home Assistant types
export interface HassEntity {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
  last_changed: string;
  last_updated: string;
  context: {
    id: string;
    parent_id: string | null;
    user_id: string | null;
  };
}

export interface HomeAssistant {
  states: Record<string, HassEntity>;
  services: Record<string, Record<string, unknown>>;
  user: {
    id: string;
    name: string;
    is_admin: boolean;
  };
  language: string;
  callService: (
    domain: string,
    service: string,
    data?: Record<string, unknown>,
    target?: { entity_id?: string | string[]; },
  ) => Promise<void>;
}

export interface CardConfig {
  type?: string;
  entity?: string;
  title?: string;
  // Add your custom config options here
}

// State Cycler specific types
export interface StateCyclerAttributes extends Record<string, unknown> {
  friendly_name?: string;
  state: string; // 'off' or entity_id
  state_friendly: string;
  index: number; // -1 if off
  toggle_state: boolean;
  include_off_state: boolean;
  last_state?: string;
  last_index?: number;
  timer_interval?: number | null;
  states: string[]; // list of entity_ids
}

export interface StateCyclerEntity extends HassEntity {
  attributes: StateCyclerAttributes;
}
