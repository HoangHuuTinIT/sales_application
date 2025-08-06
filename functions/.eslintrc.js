/* eslint-env node */
module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "no-undef": "off", // 👈 thêm dòng này
  },

  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
         node: true,
        mocha: true,
      },
      rules: {
       'no-undef': 'off',
      },
    },
  ],
  globals: {},
};
