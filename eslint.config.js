import hooks from 'eslint-plugin-react-hooks';
import tseslint from 'typescript-eslint';
export default tseslint.config(
  { ignores: ['dist/**', 'node_modules/**', 'test-results/**', 'supabase/functions/**', 'docs/**'] },
  ...tseslint.configs.recommended,
  { files: ['src/**/*.{ts,tsx}'], plugins: {'react-hooks':hooks}, linterOptions: {reportUnusedDisableDirectives:'off'}, rules: {
    '@typescript-eslint/no-explicit-any': 'off',
    'react-hooks/rules-of-hooks': 'error',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    '@typescript-eslint/no-non-null-assertion': 'off',
  } },
);
