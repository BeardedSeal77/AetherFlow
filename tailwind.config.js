/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'gradient-conic':
          'conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))',
      },
      colors: {
        base: 'var(--color-base)',
        surface: 'var(--color-surface)',
        overlay: 'var(--color-overlay)',
        muted: 'var(--color-muted)',
        subtle: 'var(--color-subtle)',
        text: 'var(--color-text)',
        love: 'var(--color-love)',
        gold: 'var(--color-gold)',
        rose: 'var(--color-rose)',
        pine: 'var(--color-pine)',
        foam: 'var(--color-foam)',
        iris: 'var(--color-iris)',
        'highlight-low': 'var(--color-highlight-low)',
        'highlight-med': 'var(--color-highlight-med)',
        'highlight-high': 'var(--color-highlight-high)',
        green: 'var(--color-green)',
        red: 'var(--color-red)',
        blue: 'var(--color-blue)',
        yellow: 'var(--color-yellow)',
      },
    },
  },
  plugins: [],
}
