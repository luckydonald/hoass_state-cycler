import { mount } from '@vue/test-utils';
import {
  beforeEach,
  describe, expect, it,
} from 'vitest';

import StateCyclerCard from '../src/StateCyclerCard.vue';

import type { CardConfig, HassEntity, HomeAssistant } from '../src/types';

describe('StateCyclerCard', () => {
  let mockHass: HomeAssistant;
  let mockConfig: CardConfig;

  beforeEach(() => {
    // Create mock Home Assistant instance
    // Build states using bracket notation to avoid object-literal property name linting
    const states: Record<string, HassEntity> = {};
    states['sensor.test'] = {
      entity_id: 'sensor.test',
      state: 'on',
      attributes: {},
      last_changed: '2024-01-01T00:00:00Z',
      last_updated: '2024-01-01T00:00:00Z',
      context: {
        id: 'test-context',
        parent_id: null,
        user_id: null,
      },
    };

    mockHass = {
      states,
      services: {},
      user: {
        id: 'test-user',
        name: 'Test User',
        is_admin: true,
      },
      language: 'en',
      callService: async () => {},
    };

    mockConfig = {
      title: 'Test Card',
    };
  });

  it('renders with title', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    expect(wrapper.text()).toContain('Test Card');
  });

  it('uses default title when not configured', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: {},
      },
    });

    expect(wrapper.text()).toContain('State Cycler');
  });

  it('displays current time', async () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    // Wait for component to mount
    await wrapper.vm.$nextTick();

    // Check that time display section exists
    expect(wrapper.find('.time-display').exists()).toBe(true);
  });

  it('displays entity state when entity is configured', () => {
    const configWithEntity: CardConfig = {
      ...mockConfig,
      entity: 'sensor.test',
    };

    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: configWithEntity,
      },
    });

    expect(wrapper.text()).toContain('sensor.test');
    expect(wrapper.text()).toContain('on');
  });

  it('shows warning when entity is not found', () => {
    const configWithEntity: CardConfig = {
      ...mockConfig,
      entity: 'sensor.nonexistent',
    };

    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: configWithEntity,
      },
    });

    expect(wrapper.text()).toContain('Entity not found');
  });

  it('does not show entity section when no entity configured', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    expect(wrapper.text()).not.toContain('Entity State');
  });

  it('handles null hass gracefully', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: null,
        config: mockConfig,
      },
    });

    expect(wrapper.exists()).toBe(true);
  });
});
