/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    // Only scan static site generator code
    "./lib/mix/tasks/build_static.ex",
    "./priv/static/static-*.js"
  ],
  theme: {
    extend: {
      colors: {
        'base-100': 'var(--color-base-100)',
        'base-200': 'var(--color-base-200)',
        'base-300': 'var(--color-base-300)',
        'base-content': 'var(--color-base-content)',
        'primary': 'var(--color-primary)',
        'blue': {
          600: '#2563eb',
        },
      },
    },
  },
  plugins: [
    // Only typography plugin, no DaisyUI (reduces CSS from 85KB to ~15KB)
    require("@tailwindcss/typography"),
  ],
}
