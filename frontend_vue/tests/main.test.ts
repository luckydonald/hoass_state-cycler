import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';

// Mock the custom elements
global.customElements = {
  define: vi.fn(),
  get: vi.fn(),
  whenDefined: vi.fn(),
} as any;

// Mock window.customCards
(global as any).window = {
  customCards: [],
};

describe('main.ts registration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should register custom elements', async () => {
    // Import the module which will trigger registration
    await import('../src/main.ts');

    // Check that customElements.define was called
    expect(global.customElements.define).toHaveBeenCalledWith(
      'plugin-template-card',
      expect.any(Function),
    );
    expect(global.customElements.define).toHaveBeenCalledWith(
      'plugin-template-card-editor',
      expect.any(Function),
    );
  });

  it('should register with Home Assistant card registry', async () => {
    await import('../src/main.ts');

    const windowObj = global.window as any;
    expect(windowObj.customCards).toBeDefined();
    expect(Array.isArray(windowObj.customCards)).toBe(true);
  });
});

