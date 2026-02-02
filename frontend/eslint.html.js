import {defineConfig} from "eslint/config";
import html from "@html-eslint/eslint-plugin";

export default defineConfig([
  {
    files: [
      "**/*.html",
    ],
    // When using the recommended rules (or "html/all" for all rules)
    extends: ["html/recommended"],
    plugins: {
      html,
    },
  },
  {
    // support for in-js javascript (i.e. templates)
    // according to the docs, this works for .js/.ts/.mjs/.cjs files
    files: [
      "**/*.html",
      "**/*.js",
      "**/*.ts",
      "**/*.cjs",
      "**/*.mjs",
    ],
    plugins: {
      html,
    },
    rules: {
      "html/attrs-newline": [
        "error",
        {
          "closeStyle": "newline",
          "ifAttrsMoreThan": 1,
        },
      ],
      "html/class-spacing": "error",
      "html/element-newline": [
        "error",
        {
          "skip": [
            "pre",
            "code",
          ],
          "inline": [
            "$inline",
          ],
        },
      ],
      "html/lowercase": "error",
      "html/no-extra-spacing-attrs": "error",
      "html/no-extra-spacing-text": "error",
      "html/no-multiple-empty-lines": "error",
      "html/no-trailing-spaces": "error",
      "html/quotes": [
        "error",
        "double",
        {
          "enforceTemplatedAttrValue": false,
        },
      ],
    },
  },
]);
