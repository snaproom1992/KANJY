import html from 'eslint-plugin-html';

export default [
  {
    files: ['KANJY/web-frontend/**/*.html'],
    plugins: {
      html
    },
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'script',
      globals: {
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',
        setTimeout: 'readonly',
        setInterval: 'readonly',
        clearTimeout: 'readonly',
        clearInterval: 'readonly',
        Promise: 'readonly',
        fetch: 'readonly',
        alert: 'readonly',
        supabase: 'writable',
        tailwind: 'readonly',
        Chart: 'readonly',
        URLSearchParams: 'readonly',
        navigator: 'readonly',
        IntersectionObserver: 'readonly'
      }
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off',
      'no-redeclare': 'error',
      'no-undef': 'warn',
      'no-dupe-keys': 'error',
      'no-duplicate-case': 'error',
      'no-func-assign': 'error'
    }
  },
  {
    ignores: [
      'node_modules/',
      '*.xcworkspace/**',
      '*.xcodeproj/**',
      'build/',
      'dist/',
      '.build/',
      '**/*.framework/**',
      'DerivedData/',
      '.DS_Store'
    ]
  }
];

