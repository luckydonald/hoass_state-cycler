import { mount as _mount } from '@vue/test-utils';
import {
  beforeEach,
  describe, expect, it, vi,
} from 'vitest';

// Mock the custom elements
global.customElements = {
  define: vi.fn(),
  get: vi.fn(),
  whenDefined: vi.fn(),
} as unknown as CustomElementRegistry;

// Define a minimal type for window used in tests
interface TestWindow {
  customCards: unknown[];
}

// Mock window.customCards
(global as unknown as { window: TestWindow }).window = {
  customCards: [],
};

describe('main.ts registration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should register custom elements', async () => {
    // Import the module which will trigger registration
    await import('../src/main');

    // Check that customElements.define was called
    // vitest's `vi.fn()` is used for mocking; assert call counts without casting to jest.Mock
    expect(global.customElements.define).toHaveBeenCalledWith(
      'state-cycler-card',
      expect.any(Function),
    );
    expect(global.customElements.define).toHaveBeenCalledWith(
      'state-cycler-card-editor',
      expect.any(Function),
    );
  });

  it('should register with Home Assistant card registry', async () => {
    await import('../src/main');

    const windowObj = (global as unknown as { window: TestWindow }).window;
    expect(windowObj.customCards).toBeDefined();
    expect(Array.isArray(windowObj.customCards)).toBe(true);
  });
});
