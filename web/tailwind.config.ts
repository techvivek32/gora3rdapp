import type { Config } from 'tailwindcss';

/**
 * Brand palette mirrors the mobile app's AppColors so a booking looks the same
 * whether the customer is on the phone or the website: primary #F97316 (orange)
 * with the deep navy #12213D used on the customer home hero.
 *
 * Everything that changes between light and dark is a CSS variable rather than
 * a fixed hex, defined in globals.css under `:root` and `[data-theme='dark']`.
 * Written as bare `R G B` channels so Tailwind's slash-opacity still works:
 * `bg-surface/70` compiles to `rgb(var(--surface) / 0.7)`.
 *
 * The orange scale stays fixed. It is the brand, and a brand that changes
 * colour with the OS setting is not a brand — only the surfaces behind it move.
 */
const themed = (v: string) => `rgb(var(${v}) / <alpha-value>)`;

const config: Config = {
  // Light is the default; `data-theme="dark"` on <html> switches, which is what
  // the toggle and the pre-paint script in layout.tsx both set.
  darkMode: ['class', '[data-theme="dark"]'],
  content: [
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#fff7ed',
          100: '#ffedd5',
          200: '#fed7aa',
          300: '#fdba74',
          400: '#fb923c',
          500: '#f97316',
          600: '#ea580c',
          700: '#c2410c',
          800: '#9a3412',
          900: '#7c2d12',
        },
        navy: '#12213D',

        /** Page background. */
        canvas: themed('--canvas'),
        /** A card, the header, the footer — anything sitting on the canvas. */
        surface: themed('--surface'),
        /** Recessed areas: a segmented track, a thumbnail well, a hover row. */
        sunken: themed('--sunken'),

        ink: themed('--ink'),
        muted: themed('--muted'),
        hairline: themed('--hairline'),

        /** A tinted panel in the brand colour — `bg-brand-50` in light, a dim
         *  wash of orange in dark, where #fff7ed would glare. */
        tint: themed('--tint'),
        /** The ring that goes with it. */
        tintline: themed('--tintline'),
        /** Brand text ON a surface: the 700 shade burns out on dark. */
        brandink: themed('--brandink'),

        /** The caution notice shown above every booking feed. */
        dangerbg: themed('--danger-bg'),
        dangerfg: themed('--danger-fg'),

        ok: '#16A34A',
        warn: '#D97706',
        bad: '#DC2626',
      },
      fontFamily: {
        sans: ['var(--font-poppins)', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        // Dark surfaces are separated by light, not by shadow, so the card
        // shadow is a variable too — it all but disappears in dark mode.
        card: 'var(--shadow-card)',
        glow: 'var(--shadow-glow)',
      },
    },
  },
  plugins: [],
};

export default config;
