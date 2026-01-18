import { describe, it, expect } from 'vitest';
import type { HomeAssistant, CardConfig, HassEntity } from '../src/types';

describe('Type Definitions', () => {
  describe('HassEntity', () => {
    it('should have required properties', () => {
      const entity: HassEntity = {
        entity_id: 'sensor.test',
        state: 'on',
        attributes: { test: 'value' },
        last_changed: '2024-01-01T00:00:00Z',
        last_updated: '2024-01-01T00:00:00Z',
        context: {
          id: 'test-id',
          parent_id: null,
          user_id: null,
        },
      };

      expect(entity.entity_id).toBe('sensor.test');
      expect(entity.state).toBe('on');
      expect(entity.attributes).toHaveProperty('test');
    });
  });

  describe('HomeAssistant', () => {
    it('should have callService method', () => {
      const hass: HomeAssistant = {
        states: {},
        services: {},
        user: {
          id: 'test',
          name: 'Test',
          is_admin: false,
        },
        language: 'en',
        callService: async () => {},
      };

      expect(typeof hass.callService).toBe('function');
    });
  });

  describe('CardConfig', () => {
    it('should allow optional properties', () => {
      const config: CardConfig = {};
      expect(config).toBeDefined();

      const configWithProps: CardConfig = {
        type: 'custom:plugin-template-card',
        entity: 'sensor.test',
        title: 'Test',
      };
      expect(configWithProps.title).toBe('Test');
    });
  });
});

