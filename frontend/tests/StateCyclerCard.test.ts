import { mount } from '@vue/test-utils';
import {
  beforeEach,
  describe, expect, it, vi,
} from 'vitest';

import StateCyclerCard from '../src/StateCyclerCard.vue';

import type { CardConfig, HomeAssistant, StateCyclerEntity } from '../src/types';

describe('StateCyclerCard', () => {
  let mockHass: HomeAssistant;
  let mockConfig: CardConfig;
  let mockEntity: StateCyclerEntity;

  beforeEach(() => {
    mockEntity = {
      entity_id: 'state_cycler.test',
      state: 'light.living_room',
      attributes: {
        friendly_name: 'Test Cycler',
        state: 'light.living_room',
        state_friendly: 'Living Room Light',
        index: 0,
        toggle_state: true,
        include_off_state: false,
        states: [
          'light.living_room',
          'light.kitchen',
          'scene.movie',
        ],
      },
      last_changed: '2024-01-01T00:00:00Z',
      last_updated: '2024-01-01T00:00:00Z',
      context: {
        id: 'test-context',
        parent_id: null,
        user_id: null,
      },
    };

    mockHass = {
      states: {
        ['state_cycler.test']: mockEntity,
      },
      services: {},
      user: {
        id: 'test-user',
        name: 'Test User',
        is_admin: true,
      },
      language: 'en',
      callService: vi.fn().mockResolvedValue(undefined),
    };

    mockConfig = {
      title: 'Test Card',
      entity: 'state_cycler.test',
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
        config: { entity: 'state_cycler.test' },
      },
    });

    expect(wrapper.text()).toContain('State Cycler');
  });

  it('displays current state info', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    expect(wrapper.text()).toContain('Living Room Light');
    expect(wrapper.text()).toContain('Index: 0');
    expect(wrapper.text()).toContain('Status: On');
    expect(wrapper.text()).toContain('Include Off: No');
  });

  it('shows buttons when entity is present', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    const buttons = wrapper.findAll('ha-button');
    expect(buttons.length).toBe(3);
    expect(buttons[0].text()).toContain('Turn Off');
    expect(buttons[1].text()).toContain('Next');
    expect(buttons[2].text()).toContain('Cycle');
  });

  it('calls switch service on toggle button click', async () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    const toggleButton = wrapper.findAll('ha-button')[0];
    await toggleButton.trigger('click');

    expect(mockHass.callService).toHaveBeenCalledWith('state_cycler', 'switch', {
      entity_id: 'state_cycler.test',
    }, {
      entity_id: 'state_cycler.test',
    });
  });

  it('calls next service on next button click', async () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    const nextButton = wrapper.findAll('ha-button')[1];
    await nextButton.trigger('click');

    expect(mockHass.callService).toHaveBeenCalledWith('state_cycler', 'next', {
      entity_id: 'state_cycler.test',
    }, {
      entity_id: 'state_cycler.test',
    });
  });

  it('calls cycle service on cycle button click', async () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    const cycleButton = wrapper.findAll('ha-button')[2];
    await cycleButton.trigger('click');

    expect(mockHass.callService).toHaveBeenCalledWith('state_cycler', 'cycle', {
      entity_id: 'state_cycler.test',
    }, {
      entity_id: 'state_cycler.test',
    });
  });

  it('displays states list', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    expect(wrapper.text()).toContain('States:');
    expect(wrapper.text()).toContain('light.living_room');
    expect(wrapper.text()).toContain('light.kitchen');
    expect(wrapper.text()).toContain('scene.movie');
  });

  it('highlights active state in list', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    const activeLi = wrapper.find('.states-list li.active');
    expect(activeLi.text()).toContain('light.living_room');
  });

  it('shows no entity message when entity not found', () => {
    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: { entity: 'state_cycler.nonexistent' },
      },
    });

    expect(wrapper.text()).toContain('No State Cycler entity configured or found.');
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

  it('shows turn on when off', () => {
    mockEntity.attributes.toggle_state = false;
    mockEntity.attributes.index = -1;
    mockEntity.attributes.state_friendly = 'Off';

    const wrapper = mount(StateCyclerCard, {
      props: {
        hass: mockHass,
        config: mockConfig,
      },
    });

    expect(wrapper.text()).toContain('Status: Off');
    const toggleButton = wrapper.findAll('ha-button')[0];
    expect(toggleButton.text()).toContain('Turn On');
  });
});
