import type { Metadata, Viewport } from 'next';
import { Poppins } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';
import { SiteHeader } from '@/components/SiteHeader';
import { SiteFooter } from '@/components/SiteFooter';
import { IntroLoader } from '@/components/IntroLoader';

// Poppins is the mobile app's font, so the two surfaces read as one product.
const poppins = Poppins({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700', '800', '900'],
  variable: '--font-poppins',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Gora Cabs — Book a cab, hire a driver, share a ride',
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
    <html lang="en" className={poppins.variable} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOTSTRAP + INTRO_BOOTSTRAP }} />
      </head>
      <body className="min-h-screen font-sans">
        <Providers>
          <IntroLoader />
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
