import type { Config } from 'tailwindcss';

/**
 * Brand palette mirrors the mobile app's AppColors so a booking looks the same
 * whether the customer is on the phone or the website: primary #F97316 (orange)
 * with the deep navy #12213D used on the customer home hero.
 */
const config: Config = {
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
        ink: '#111827',
        muted: '#6B7280',
        hairline: '#E5E7EB',
        ok: '#16A34A',
        warn: '#D97706',
        bad: '#DC2626',
      },
      fontFamily: {
        sans: ['var(--font-poppins)', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        card: '0 1px 3px rgba(17,24,39,0.06), 0 8px 24px rgba(17,24,39,0.06)',
      },
    },
  },
  plugins: [],
};

export default config;
