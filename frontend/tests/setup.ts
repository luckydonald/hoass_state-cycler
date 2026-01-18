import { beforeAll, afterEach } from 'vitest';
import { cleanup } from '@vue/test-utils';

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
  whenDefined: () => Promise.resolve(),
} as any;

// Mock window.customCards
(global as any).window = {
  customCards: [],
};

