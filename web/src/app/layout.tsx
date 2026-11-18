import type { Metadata, Viewport } from 'next';
import { Montserrat, Poppins } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';
import { SiteHeader } from '@/components/SiteHeader';
import { SiteFooter } from '@/components/SiteFooter';
import { IntroLoader } from '@/components/IntroLoader';
import { ScrollFx } from '@/components/ScrollFx';

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
  title: 'Gora Taxi — Book a cab, hire a driver, share a ride',
  description:
    'Book outstation and local cabs, hire a driver for your own car, or share a ride across India. India Ka Apna App.',
  // Without this the browser asks for /favicon.ico on every page, gets a 404
  // and shows a blank tab. The mark is the one already in the header.
  icons: { icon: '/gora-logo.png', apple: '/gora-logo.png' },
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
    <html lang="en" className={`${poppins.variable} ${montserrat.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: JS_FLAG + INTRO_BOOTSTRAP }} />
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
        </Providers>
      </body>
    </html>
  );
}
