import type { Config } from 'tailwindcss';

/**
 * Brand palette mirrors the mobile app's AppColors so a booking looks the same
 * whether the customer is on the phone or the website: primary #F97316
 * (orange), carried on a warm near-black rather than the old navy.
 *
 * The navy went because navy-and-orange was the half of the palette that
 * could go: the orange is the logo, the buttons and the app, and a brand that
 * changes colour between the phone and the website is not a brand. Black and
 * bone is a far more expensive pairing with it than blue ever was.
 *
 * The site is light only. The surfaces, bands and service colours are still
 * CSS variables rather than fixed hexes, defined once on `:root` in
 * globals.css, so a palette change stays a palette change instead of a
 * find-and-replace across two hundred elements. Written as bare `R G B`
 * channels so Tailwind's slash-opacity keeps working: `bg-surface/70`
 * compiles to `rgb(var(--surface) / 0.7)`.
 */
const themed = (v: string) => `rgb(var(${v}) / <alpha-value>)`;

const config: Config = {
  content: [
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
    /*
     * `src/lib` builds class strings too — `cityChip` picks a chip's colour
     * and `statusPill` picks a booking status's — and Tailwind only emits a
     * utility it has SEEN in a scanned file. Leaving this folder out meant
     * those classes existed only while some page happened to spell the same
     * name out; the moment the home page stopped using `bg-cabsolid`, every
     * teal city chip rendered as a white pill with white text on it. A class
     * name decided in a helper is still a class name.
     */
    './src/lib/**/*.{js,ts,jsx,tsx,mdx}',
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
        /** The dark end of the page. Blue-black, because the logo is blue
         *  and orange and the dark bands are the only place the blue gets
         *  to be the surface rather than an accent. */
        midnight: '#0B1E3F',

        /** The structural blue, straight off the logo's own #0020A0 family.
         *  Orange stays the action colour; this one carries everything that
         *  is not asking to be clicked. */
        blue: themed('--blue'),
        blueink: themed('--blueink'),
        bluesoft: themed('--blue-soft'),
        blueline: themed('--blue-line'),
        /** A whole band of blue — the one area of the page that is
         *  unmistakably the brand colour rather than a tint of it. */
        bandblue: themed('--band-blue'),

        /**
         * One colour per service.
         *
         * The brand stays orange — it is the logo, the buttons and the app —
         * but a page that offers three different things in three identical
         * orange cards makes the reader do the sorting. Giving Cab, Hire a
         * Driver and Car Pool a colour each lets someone find their service
         * before they have read a word, and it is what makes an otherwise
         * restrained, typographic layout feel colourful.
         *
         */
        cab: themed('--svc-cab'),
        cabsoft: themed('--svc-cab-soft'),
        drive: themed('--svc-drive'),
        drivesoft: themed('--svc-drive-soft'),
        pool: themed('--svc-pool'),
        poolsoft: themed('--svc-pool-soft'),
        lux: themed('--svc-lux'),
        luxsoft: themed('--svc-lux-soft'),

        /** The same four as a BLOCK colour, with white text on top. */
        cabsolid: themed('--svc-cab-solid'),
        drivesolid: themed('--svc-drive-solid'),
        poolsolid: themed('--svc-pool-solid'),
        luxsolid: themed('--svc-lux-solid'),

        /** Full-width section washes. A page of grey bands is not colourful
         *  however colourful its icons are. */
        bandwarm: themed('--band-warm'),
        bandcool: themed('--band-cool'),
        bandmint: themed('--band-mint'),
        banddeep: themed('--band-deep'),

        /** Page background. */
        canvas: themed('--canvas'),
        /** A card, the header, the footer — anything sitting on the canvas. */
        surface: themed('--surface'),
        /** Recessed areas: a segmented track, a thumbnail well, a hover row. */
        sunken: themed('--sunken'),

        ink: themed('--ink'),
        muted: themed('--muted'),
        hairline: themed('--hairline'),

        /** A tinted panel in the brand colour. */
        tint: themed('--tint'),
        /** The ring that goes with it. */
        tintline: themed('--tintline'),
        /** Brand text ON a surface, at a shade that holds AA on white. */
        brandink: themed('--brandink'),

        /**
         * The accent, in the role the reference gives its yellow: the Book
         * button, the section eyebrows, every second icon tile.
         *
         * `accentink` is the text that goes ON it, and it is dark on purpose.
         * White on #F97316 measures 2.80:1 and had been failing on this site
         * since it was built; gray-800 on it is 5.24:1. The reference reaches
         * the same answer with its yellow, and dark-on-warm is most of why
         * that button reads as a button and not as a warning.
         */
        accent: themed('--accent'),
        accenthover: themed('--accent-hover'),
        accentink: themed('--accent-ink'),
        accentsoft: themed('--accent-soft'),

        /** The caution notice shown above every booking feed. */
        dangerbg: themed('--danger-bg'),
        dangerfg: themed('--danger-fg'),

        ok: '#16A34A',
        warn: '#D97706',
        bad: '#DC2626',
      },
      fontFamily: {
        /*
         * The fallback goes INSIDE the var(), not after it.
         *
         * `['var(--font-sans)', 'system-ui', 'sans-serif']` compiles to
         * `font-family: var(--font-sans), system-ui, sans-serif`, and if the
         * variable is ever undefined that whole declaration is invalid CSS —
         * the browser drops it and falls all the way back to its default
         * serif. Measured: every heading and paragraph on the site rendered
         * in Times New Roman when the font chunk failed to load. Written this
         * way the missing variable degrades to system-ui, which is the point
         * of having a fallback at all.
         */
        sans: ['var(--font-sans, system-ui)', 'system-ui', 'sans-serif'],
        /**
         * Headlines only — see the note in layout.tsx. Its fallback is a
         * sans, not a serif: if the webfont never arrives, a heading set in
         * Georgia next to Inter body copy looks like a mistake, where one
         * set in the system sans just looks plain.
         */
        display: ['var(--font-display, system-ui)', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        card: 'var(--shadow-card)',
        /** The hover state of a card, and the resting state of the two
         *  panels that are meant to float: the booking form and the app
         *  band's inset card. */
        lift: 'var(--shadow-lift)',
        glow: 'var(--shadow-glow)',
      },
      borderRadius: {
        /** 24px is the radius the reference uses for every card — 51 of them
         *  measured against 25 at 16px — so it gets a name rather than being
         *  spelled `rounded-[24px]` on every element. */
        card: '24px',
        tile: '16px',
      },
      maxWidth: {
        /** The measure the reference sets its body copy and FAQ to. */
        readable: '46rem',
      },
    },
  },
  plugins: [],
};

export default config;
