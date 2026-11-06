const defaultTheme = require('tailwindcss/defaultTheme')
const colors = require('tailwindcss/colors')

// Omit deprecated aliases so reading them doesn't print Tailwind warnings.
const DEPRECATED_COLORS = ['lightBlue', 'warmGray', 'trueGray', 'coolGray', 'blueGray']

module.exports = {
  content: [
    './src/**/*.{erb,yml,js}',
    './lib/**/*.rb',
    // DOCS_SITE_OUT is set by the builder so a non-default --out dir is scanned too.
    `${process.env.DOCS_SITE_OUT || './_site'}/**/*.html`,
  ],
  darkMode: 'selector',
  theme: {
    extend: {
      fontSize: {
        'xs': '.81rem',
        '2xs': ['0.65rem', { lineHeight: '0.9rem', letterSpacing: '1px' }]
      },
      colors: ({ colors }) => ({
        primary: {
          50: 'var(--primary-50)',
          100: 'var(--primary-100)',
          200: 'var(--primary-200)',
          300: 'var(--primary-300)',
          400: 'var(--primary-400)',
          500: 'var(--primary-500)',
          600: 'var(--primary-600)',
          700: 'var(--primary-700)',
          800: 'var(--primary-800)',
          900: 'var(--primary-900)',
        },

        secondary: {
          50: 'var(--secondary-50)',
          100: 'var(--secondary-100)',
          200: 'var(--secondary-200)',
          300: 'var(--secondary-300)',
          400: 'var(--secondary-400)',
          500: 'var(--secondary-500)',
          600: 'var(--secondary-600)',
          700: 'var(--secondary-700)',
          800: 'var(--secondary-800)',
          900: 'var(--secondary-900)',
        },
        base: colors.slate,
        ...Object.fromEntries(
          Object.keys(colors)
            .filter((name) => !DEPRECATED_COLORS.includes(name))
            .map((name) => [name, colors[name]])
        ),
      }),
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
