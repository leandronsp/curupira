/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    // Only scan static site generator code
    "./lib/mix/tasks/build_static.ex",
    "./priv/static/static-*.js"
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("daisyui"),
  ],
  daisyui: {
    themes: ["light", "dark"],
  },
}
