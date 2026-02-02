// Local ESLint plugin that marks template literals assigned to .innerHTML with /* html */
export const rules = {
  'mark-html': {
    meta: {
      type: 'suggestion',
      docs: { description: 'Mark template literals assigned to innerHTML with /* html */ so html-eslint can lint them', recommended: false },
      fixable: 'code',
      schema: [],
    },
    create(context) {
      return {
        AssignmentExpression(node) {
          try {
            const left = node.left;
            const right = node.right;
            // Only handle MemberExpression like foo.innerHTML
            if (!left || left.type !== 'MemberExpression') return;
            const prop = left.property;
            const propName = prop.type === 'Identifier' ? prop.name : (prop.type === 'Literal' ? String(prop.value) : null);
            if (propName !== 'innerHTML') return;
            // Only handle template literals with no expressions
            if (!right || right.type !== 'TemplateLiteral') return;
            if (right.expressions && right.expressions.length > 0) return;
            // Check if already has a leading Block or Line comment that contains 'html'
            const sourceCode = context.getSourceCode();
            const tokenBefore = sourceCode.getTokenBefore(right);
            if (tokenBefore) {
              const comments = sourceCode.getCommentsBefore(right);
              for (const c of comments) {
                if (c.type === 'Block' && c.value.trim().toLowerCase().includes('html')) return;
              }
            }
            // Report and offer fix: insert /* html */ before the template literal
            context.report({
              node: right,
              message: 'Mark this template literal as HTML for html-eslint',
              fix(fixer) {
                return fixer.insertTextBefore(right, '/* html */ ');
              },
            });
          } catch (e) {
            // ignore
          }
        }
      };
    }
  }
};

export default { rules };
