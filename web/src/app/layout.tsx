import type { Metadata, Viewport } from 'next';
import localFont from 'next/font/local';
import './globals.css';
import { Providers } from './providers';
import { SiteHeader } from '@/components/SiteHeader';
import { SiteFooter } from '@/components/SiteFooter';
import { IntroLoader } from '@/components/IntroLoader';
import { ScrollFx } from '@/components/ScrollFx';

/**
 * Headlines. Melodrama, from Fontshare.
 *
 * Seventh face, and the first that is not a sans. Six respectable
 * grotesques were each rejected as "simple", which stopped being a matter
 * of taste and started being evidence: the category was the problem, not
 * the pick. Melodrama is a display serif with a dramatic thick-to-thin —
 * nothing on an orange taxi site looks less like a template.
 *
 * Display sizes only. The thin strokes that make it distinctive are the
 * ones that disappear at 13px, which is why the body is Satoshi.
 */
const melodrama = localFont({
  src: [
    { path: './fonts/Melodrama-500.woff2', weight: '500', style: 'normal' },
    { path: './fonts/Melodrama-600.woff2', weight: '600', style: 'normal' },
    { path: './fonts/Melodrama-700.woff2', weight: '700', style: 'normal' },
  ],
  variable: '--font-display',
  display: 'swap',
  // Metrics matched to a serif this time, so the swap does not shift.
  adjustFontFallback: 'Times New Roman',
});

/**
 * Everything that is read. Satoshi, from Fontshare.
 *
 * Four cuts: 400, 500, 700, 900. The family has no 600 and no 800, so a
 * `font-semibold` resolves to 700 and a `font-extrabold` to 900 by the
 * normal CSS matching rules. Both are real cuts — nothing is synthesised,
 * which is the part that matters.
 */
const satoshi = localFont({
  src: [
    { path: './fonts/Satoshi-400.woff2', weight: '400', style: 'normal' },
    { path: './fonts/Satoshi-500.woff2', weight: '500', style: 'normal' },
    { path: './fonts/Satoshi-700.woff2', weight: '700', style: 'normal' },
    { path: './fonts/Satoshi-900.woff2', weight: '900', style: 'normal' },
  ],
  variable: '--font-sans',
  display: 'swap',
  adjustFontFallback: 'Arial',
});


export const metadata: Metadata = {
  title: 'Gora Taxi — Book a cab, hire a driver, share a ride',
  description:
    'Book outstation and local cabs, hire a driver for your own car, or share a ride across India. India Ka Apna App.',
};

export const viewport: Viewport = {
  themeColor: '#F97316',
  width: 'device-width',
  initialScale: 1,
};

/**
 * Settles the theme before the browser paints anything.
 *
 * It has to be inline and in `<head>`: an external or deferred script runs
 * after first paint, so the visitor would see a white flash before a dark page
 * — worst at night, which is exactly when dark mode is on.
 *
 * It always writes an explicit `light` or `dark` rather than leaving the
 * attribute off for "follow the system". ThemeToggle leans on that to pick its
 * icon in CSS, which is what keeps the server and client markup identical.
 */
const THEME_BOOTSTRAP = `(function(){try{
var s=localStorage.getItem('gora-theme');
var d=s==='dark'||(!s&&window.matchMedia('(prefers-color-scheme: dark)').matches);
document.documentElement.dataset.theme=d?'dark':'light';
}catch(e){document.documentElement.dataset.theme='light';}})();`;

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
    // `suppressHydrationWarning`: the scripts below set data-theme and
    // data-intro on this very element before React hydrates, so the attributes
    // it finds will not match the server's. That difference is the point.
    <html lang="en" className={`${satoshi.variable} ${melodrama.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: JS_FLAG + THEME_BOOTSTRAP + INTRO_BOOTSTRAP }} />
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
