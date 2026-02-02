import { cleanup } from '@vue/test-utils';
import { afterEach, beforeAll } from 'vitest';

// Setup function that runs before all tests
beforeAll(() => {
  // Mock console methods to reduce noise in tests
  global.console.info = () => {};
});

// Cleanup after each test
afterEach(() => {
  cleanup();
});

// Mock Home Assistant custom elements
global.customElements = {
  define: () => {},
  get: () => undefined,
  whenDefined: async () => Promise.resolve(),
} as unknown as CustomElementRegistry;

// Mock window.customCards
(global as unknown).window = {
  customCards: [],
};
