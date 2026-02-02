#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Load eslint config from frontend/.eslintrc.cjs if available to honor ignore lists
const eslintConfigPath = path.join(process.cwd(), 'frontend', '.eslintrc.cjs');
let eslintIgnore = [];
let eslintIgnoreParents = [];
if (fs.existsSync(eslintConfigPath)) {
  try {
    // eslint config is a CJS module
    // eslint-disable-next-line global-require, import/no-dynamic-require
    const eslintrc = require(eslintConfigPath);
    const rule = eslintrc && eslintrc.rules && eslintrc.rules['vue/no-deprecated-slot-attribute'];
    if (Array.isArray(rule)) {
      const config = rule[1] || {};
      if (config && typeof config === 'object') {
        eslintIgnore = Array.isArray(config.ignore) ? config.ignore : [];
        eslintIgnoreParents = Array.isArray(config.ignoreParents) ? config.ignoreParents : [];
      }
    }
  } catch (err) {
    // If loading fails, just continue with empty ignore lists
    // console.warn('Failed to load eslint config:', err.message);
  }
}

function walk(dir) {
  const res = [];
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      if (ent.name === 'node_modules' || ent.name === 'dist') continue;
      res.push(...walk(p));
    } else if (ent.isFile() && p.endsWith('.vue')) {
      res.push(p);
    }
  }
  return res;
}

function checkFile(file) {
  const text = fs.readFileSync(file, 'utf8');
  // Regex that matches open/close tags and captures slash, tag name and attributes
  // Example matches: <div class="x">, </div>, <img src="" />
  const tagRegex = /<\s*(\/?)\s*([a-zA-Z0-9-]+)([^>]*)>/g;
  const stack = [];
  const problems = [];
  let m;

  while ((m = tagRegex.exec(text))) {
    const isClose = m[1] === '/';
    const tag = m[2];
    const attrs = m[3] || '';

    // Determine if self-closing like <br /> or <img .../> by checking attrs trailing slash
    const isSelfClose = /\/\s*$/.test(attrs.trim());

    if (!isClose) {
      // Opening tag: parent is current top of stack
      const parent = stack.length ? stack[stack.length - 1].tag : null;

      // Find slot attribute (support single or double quotes)
      const slotMatch = attrs.match(/\bslot\s*=\s*['\"]([^'\"]+)['\"]/);
      if (slotMatch) {
        const slot = slotMatch[1];

        // Normalize tag and parent to lower-case for comparison
        const tagNorm = (tag || '').toLowerCase();
        const parentNorm = parent ? parent.toLowerCase() : null;

        // If tag itself is ha-* it's allowed
        let allowed = tagNorm.startsWith('ha-');

        // Allow if parent is ha-*
        if (!allowed && parentNorm && parentNorm.startsWith('ha-')) allowed = true;

        // Allow if tag is explicitly ignored in eslint config
        if (!allowed && eslintIgnore.includes(tagNorm)) allowed = true;

        // Allow if parent is explicitly listed in eslintIgnoreParents
        if (!allowed && parentNorm && eslintIgnoreParents.includes(parentNorm)) allowed = true;

        if (!allowed) {
          const upTo = text.slice(0, m.index);
          const line = upTo.split('\n').length;
          problems.push({ file, line, tag, slot, attrs });
        }
      }

      // Push non-self-closing opening tags to stack
      if (!isSelfClose) {
        stack.push({ tag, index: m.index });
      }
    } else {
      // Closing tag: pop matching opening tag if present
      for (let i = stack.length - 1; i >= 0; i--) {
        if (stack[i].tag === tag) {
          stack.splice(i, 1);
          break;
        }
      }
    }
  }

  return problems;
}

function main() {
  const base = process.argv[2] || '.';
  const files = walk(base);
  const all = [];
  for (const f of files) {
    all.push(...checkFile(f));
  }
  if (all.length) {
    console.error('Found slot attributes on non-ha-* elements (and no ha-* parent):');
    for (const p of all) {
      console.error(`${p.file}:${p.line}: <${p.tag}> uses slot="${p.slot}"`);
    }
    process.exitCode = 2;
  } else {
    console.log('No problems found.');
  }
}

main();
