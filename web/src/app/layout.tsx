import type { Metadata, Viewport } from 'next';
import { Montserrat, Poppins } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';
import { SiteHeader } from '@/components/SiteHeader';
import { SiteFooter } from '@/components/SiteFooter';
import { AppDownloadPrompt } from '@/components/AppDownloadPrompt';
import { IntroLoader } from '@/components/IntroLoader';
import { ScrollFx } from '@/components/ScrollFx';
import { JsonLd } from '@/components/JsonLd';
import { SITE_URL } from '@/lib/seo';
import { COMPANY } from '@/lib/company';

/**
 * Headlines. Montserrat.
 *
 * The pairing the whole page is built on, and it is a deliberate swap away
 * from Cabinet Grotesk. Cabinet is a characterful display face — flat-cut
 * terminals, tight apertures — and it made the page read as a design studio's
 * site. This is a cab booking site, and the reference it is modelled on uses
 * the plainest possible geometric sans at a heavy weight. Plain is the point:
 * nothing about the lettering competes with the price and the Book button.
 *
 * 600/700/800 only. The headings are set at 700, with 800 reserved for the
 * one hero line, so the browser never has to synthesise a weight.
 */
const montserrat = Montserrat({
  subsets: ['latin'],
  weight: ['600', '700', '800'],
  variable: '--font-display',
  display: 'swap',
});

/**
 * Everything that is read. Poppins.
 *
 * Geometric like Montserrat, so the two do not argue, but with a taller
 * x-height and rounder bowls that keep 14px body copy legible on a phone.
 *
 * `latin` only: Poppins also ships Devanagari, and pulling that subset in
 * would more than double the download for the handful of Hindi words the
 * site actually uses — those fall back to the system face, which is what
 * renders them anyway on most Indian phones.
 */
const poppins = Poppins({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-sans',
  display: 'swap',
});


export const metadata: Metadata = {
  // Every page's canonical, Open Graph and JSON-LD URL is resolved against
  // this. Without it Next emits relative canonicals, which a search engine
  // reads against whatever host served the page — so a site reachable at both
  // the apex and www ends up competing with itself.
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'Gora Taxi — Outstation & Local Cab Booking in India',
    // Pages set the part before the dash; the brand is appended once, here, so
    // no page has to remember to add it and none of them says it twice.
    template: '%s | Gora Taxi',
  },
  description:
    'Book outstation and local cabs at a fixed, distance-based fare — one way, round trip or hourly. Verified drivers, no hidden charges, free cancellation.',
  applicationName: COMPANY.brand,
  keywords: [
    'cab booking',
    'outstation cab',
    'taxi service',
    'one way cab',
    'round trip taxi',
    'local cab rental',
    'intercity taxi India',
  ],
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    siteName: COMPANY.brand,
    locale: 'en_IN',
    url: SITE_URL,
    title: 'Gora Taxi — Outstation & Local Cab Booking in India',
    description:
      'Fixed, distance-based cab fares across India. One way, round trip and hourly rentals with verified drivers.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Gora Taxi — Outstation & Local Cab Booking in India',
    description:
      'Fixed, distance-based cab fares across India. One way, round trip and hourly rentals with verified drivers.',
  },
  robots: {
    index: true,
    follow: true,
    // Let Google show a full-size preview and as long a text snippet as it
    // likes. The default caps the snippet, which on a fare page means the
    // price — the one thing a searcher is deciding on — gets cut off.
    googleBot: { index: true, follow: true, 'max-snippet': -1, 'max-image-preview': 'large', 'max-video-preview': -1 },
  },
  // Without this the browser asks for /favicon.ico on every page, gets a 404
  // and shows a blank tab. The mark is the one already in the header.
  icons: { icon: '/gora-logo.png', apple: '/gora-logo.png' },

  /**
   * Proof to Google and Bing that whoever is asking for this site's search data
   * controls the site.
   *
   * Read from the environment rather than written in, so claiming the site in
   * Search Console is one line in `.env` and a restart — not a code change, a
   * commit and a deploy. Both are left out of the HTML entirely when unset,
   * which is why an empty value is filtered rather than rendered blank.
   *
   * Only needed for the HTML-tag method. Verifying the DOMAIN property with a
   * DNS TXT record is better — it covers www, the apex and every subdomain at
   * once — and needs nothing here at all.
   */
  verification: {
    ...(process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION
      ? { google: process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION }
      : {}),
    ...(process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION
      ? { other: { 'msvalidate.01': process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION } }
      : {}),
  },
};

/**
 * Who the site belongs to, said once for the whole site.
 *
 * Carried on every page so a search engine can tie the brand, the registered
 * company, the address and the app listing together into one entity instead of
 * guessing that the "Gora Taxi" on a route page is the same business as the
 * one in the footer.
 */
const ORGANISATION_JSONLD = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  '@id': `${SITE_URL}/#organization`,
  name: COMPANY.brand,
  legalName: COMPANY.legalName,
  url: SITE_URL,
  logo: `${SITE_URL}/gora-logo.png`,
  slogan: COMPANY.tagline,
  address: {
    '@type': 'PostalAddress',
    streetAddress: COMPANY.address,
    addressCountry: 'IN',
  },
  taxID: COMPANY.gstin,
  areaServed: { '@type': 'Country', name: 'India' },
  sameAs: [COMPANY.playStoreUrl].filter(Boolean),
};

const WEBSITE_JSONLD = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  '@id': `${SITE_URL}/#website`,
  url: SITE_URL,
  name: COMPANY.brand,
  publisher: { '@id': `${SITE_URL}/#organization` },
  inLanguage: 'en-IN',
};

export const viewport: Viewport = {
  // The top strip of the page, which is the blue utility bar — so the phone's
  // status bar runs into it rather than cutting across it.
  themeColor: '#0086D6',
  width: 'device-width',
  initialScale: 1,
};

/**
 * Records that scripting is on, which the reveal-on-scroll styles key off.
 *
 * Those styles park an element at `opacity: 0` until ScrollFx says otherwise.
 * With no JavaScript, ScrollFx never says otherwise, and the measured result
 * was nine invisible sections — the entire page below the fold, gone, for a
 * crawler or anyone with scripts blocked. Scoping the hidden state to this
 * attribute means the default is a plain, visible page and the animation is
 * the enhancement, which is the right way round.
 */
const JS_FLAG = `document.documentElement.dataset.js='on';`;

/**
 * Runs the opening sequence — all of it, here, not in React.
 *
 * It decides whether to play before first paint, so neither answer flashes the
 * wrong thing for a frame. It plays once a SESSION rather than once a page
 * view: a splash on every click through the site would be an obstacle, not a
 * flourish. Reduced motion never sees it at all.
 *
 * The skip listeners are attached HERE rather than in the component, and that
 * is the point of putting this in the head. Hooked up in a `useEffect` they
 * only exist once React has hydrated — on a slow phone that can be a second or
 * more after the overlay is on screen, so the one person most likely to want
 * past it is the one person who cannot get past it. Tested: tapping during
 * that window genuinely did nothing. From here it works on the first frame.
 */
const INTRO_BOOTSTRAP = `(function(){try{
var r=document.documentElement;
var seen=sessionStorage.getItem('gora-intro');
var still=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if(seen||still){r.dataset.intro='done';return;}
var done=function(){
if(r.dataset.intro==='done')return;
r.dataset.intro='done';
try{sessionStorage.setItem('gora-intro','1');}catch(e){}
};
['pointerdown','keydown','wheel','touchstart'].forEach(function(t){
window.addEventListener(t,done,{once:true,passive:true});
});
setTimeout(done,2100);
}catch(e){document.documentElement.dataset.intro='done';}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    // `suppressHydrationWarning`: the scripts below set data-js and data-intro
    // on this very element before React hydrates, so the attributes it finds
    // will not match the server's. That difference is the point.
    // `en-IN`, not plain `en`: the fares are rupees, the cities are Indian and
    // the audience is searching from India. It costs nothing and tells a search
    // engine which English this is.
    <html lang="en-IN" className={`${poppins.variable} ${montserrat.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: JS_FLAG + INTRO_BOOTSTRAP }} />
        <JsonLd data={[ORGANISATION_JSONLD, WEBSITE_JSONLD]} />
      </head>
      <body className="min-h-screen font-sans">
        <Providers>
          <IntroLoader />
          <ScrollFx />
          <div className="flex min-h-screen flex-col">
            <SiteHeader />
            <main className="flex-1">{children}</main>
            <SiteFooter />
          </div>
          {/* Sits outside the column so it pins to the viewport, not the page. */}
          <AppDownloadPrompt />
        </Providers>
      </body>
    </html>
  );
}
