'use client';

import { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import { X, Star } from 'lucide-react';
import { useSiteText } from '@/lib/site-text';

/**
 * The recurring "get the app" prompt.
 *
 * The badges elsewhere on the site are passive — they work only for someone
 * already looking at the footer. This is the one that goes and asks. It slides
 * up from the bottom once the visitor has shown they are actually reading, and
 * it comes back on later visits rather than being dismissed for good.
 *
 * **Why a bottom sheet and not a full-screen popup.** Google demotes mobile
 * pages that cover the content with an interstitial when a visitor arrives from
 * search — a banner pinned to the bottom edge is explicitly exempt. A
 * full-screen version of this would cost search traffic on every page it
 * appears on, which is a bad trade for an app install.
 */

/** How long a dismissal lasts before the prompt may show again. */
const SNOOZE_HOURS = 6;

/** Nothing shows until the visitor has been here this long… */
const DELAY_MS = 7000;

/** …or has scrolled this far, whichever happens first. */
const SCROLL_TRIGGER = 0.2;

const KEY = 'gora-app-prompt';

/** Reading storage can throw (private mode, blocked cookies) — never let it break the page. */
function snoozedUntil(): number {
  try {
    return Number(window.localStorage.getItem(KEY)) || 0;
  } catch {
    return 0;
  }
}

function snooze() {
  try {
    window.localStorage.setItem(KEY, String(Date.now() + SNOOZE_HOURS * 3600_000));
  } catch {
    /* Storage unavailable: the prompt simply returns next page view. */
  }
}

export function AppDownloadPrompt() {
  const t = useSiteText();
  const play = t('company.playStoreUrl');
  const appStore = t('company.appStoreUrl');

  const [open, setOpen] = useState(false);
  const [leaving, setLeaving] = useState(false);
  // Guards against the scroll listener and the timer both firing.
  const shown = useRef(false);

  useEffect(() => {
    if (!play && !appStore) return;
    if (Date.now() < snoozedUntil()) return;

    const show = () => {
      if (shown.current) return;
      shown.current = true;
      setOpen(true);
    };

    const timer = window.setTimeout(show, DELAY_MS);
    const onScroll = () => {
      const h = document.documentElement.scrollHeight - window.innerHeight;
      if (h > 0 && window.scrollY / h >= SCROLL_TRIGGER) show();
    };
    window.addEventListener('scroll', onScroll, { passive: true });

    return () => {
      window.clearTimeout(timer);
      window.removeEventListener('scroll', onScroll);
    };
  }, [play, appStore]);

  if (!open || (!play && !appStore)) return null;

  const close = () => {
    // Let the slide-down finish before the node goes, so it does not vanish.
    setLeaving(true);
    snooze();
    window.setTimeout(() => setOpen(false), 220);
  };

  return (
    <div
      role="dialog"
      aria-label="Get the Gora Taxi app"
      className={`fixed inset-x-0 bottom-0 z-50 px-3 pb-3 transition-transform duration-200 motion-reduce:transition-none ${
        leaving ? 'translate-y-full' : 'translate-y-0'
      }`}
      style={{ paddingBottom: 'max(0.75rem, env(safe-area-inset-bottom))' }}
    >
      {/* Everything here is `shrink-0` except the text, and the text truncates.
          A 390px phone has room for the logo, the badge and the close button
          and little else — letting the copy wrap turns a one-line bar into a
          four-line block that covers the page. */}
      <div className="mx-auto flex max-w-xl items-center gap-2.5 rounded-2xl border border-hairline bg-surface px-3 py-2.5 shadow-[0_8px_30px_rgba(0,0,0,0.18)] sm:gap-3 sm:px-3.5 sm:py-3">
        {/* The logo is a wordmark, so it is ~85px wide even at h-8 — on a 360px
            phone that is the difference between the sentence fitting and being
            cut off. The brand name sits right beside it in text, so below `sm`
            the picture is the redundant one and it goes. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/gora-logo.png" alt="" className="hidden h-10 w-auto shrink-0 sm:block" />

        <div className="min-w-0 flex-1">
          <p className="truncate text-[14px] font-bold leading-tight text-ink sm:text-[15px]">
            {t('company.brand')}
          </p>
          {/* The star is the first thing to go on a 360px phone — it is
              decoration, and the sentence is not. */}
          <p className="flex items-center gap-1 text-[11.5px] leading-tight text-ink/70 sm:text-[12.5px]">
            <Star className="hidden h-3 w-3 shrink-0 fill-amber-400 text-amber-400 sm:block" />
            <span className="truncate">Track your driver live</span>
          </p>
        </div>

        {play ? (
          <a
            href={play}
            target="_blank"
            rel="noreferrer"
            onClick={close}
            className="shrink-0"
            aria-label="Get it on Google Play"
          >
            <Image
              src="/badges/google-play.png"
              alt="Get it on Google Play"
              width={122}
              height={47}
              className="h-auto w-[96px] sm:w-[118px]"
            />
          </a>
        ) : null}

        <button
          type="button"
          onClick={close}
          aria-label="Not now"
          className="-mr-1 grid h-7 w-7 shrink-0 place-items-center rounded-full text-ink/45 transition hover:bg-sunken hover:text-ink"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
