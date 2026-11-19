'use client';

import Image from 'next/image';
import { useSiteText } from '@/lib/site-text';

/**
 * The app's store badges, and the blocks that carry them.
 *
 * Everything that links to the app goes through this file. The site asks for
 * the download in seven places now, and seven hand-written buttons would mean
 * seven chances for one of them to keep pointing at an old listing after the
 * app is renamed, re-published or ported to iOS. The URL is read from
 * `company.playStoreUrl`, which the operator edits in the admin panel, so a
 * change there reaches every badge at once.
 *
 * The artwork is Google's own badge, downloaded from their badge page rather
 * than redrawn. Google's brand guidelines ask for the supplied asset, and a
 * hand-made imitation is both against those terms and less recognisable —
 * recognisability being the entire reason to show a badge instead of a link.
 *
 * iOS: there is no App Store listing. The only identifier this product has is
 * `com.taxi.call_taxi_partner`, an Android package, and inventing a
 * `apps.apple.com` URL would ship a dead link on a real business's website.
 * The Apple badge therefore renders only once `company.appStoreUrl` has a
 * value — the day the app is published, filling that field in the admin panel
 * turns it on everywhere this component is used, with no code change.
 */

/** Official badge is 646×250; these keep that ratio exactly. */
const SIZES = {
  sm: { w: 135, h: 52 },
  md: { w: 162, h: 63 },
  lg: { w: 186, h: 72 },
} as const;

export function StoreBadges({
  size = 'md',
  className = '',
}: {
  size?: keyof typeof SIZES;
  className?: string;
}) {
  const t = useSiteText();
  const play = t('company.playStoreUrl');
  const appStore = t('company.appStoreUrl');
  const { w, h } = SIZES[size];

  if (!play && !appStore) return null;

  return (
    <div className={`flex flex-wrap items-center gap-3 ${className}`}>
      {play && (
        <a
          href={play}
          target="_blank"
          rel="noreferrer"
          /* The badge is the link's whole visible content, so the accessible
             name has to come from the image's alt text, not from a label that
             is not there. */
          className="inline-block rounded-xl transition hover:opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue"
        >
          <Image
            src="/badges/google-play.png"
            alt="Get it on Google Play"
            width={w}
            height={h}
            className="h-auto"
            /* Above the fold in the hero, so do not wait for it. */
            priority={size === 'lg'}
          />
        </a>
      )}
      {appStore && (
        <a
          href={appStore}
          target="_blank"
          rel="noreferrer"
          className="inline-block rounded-xl transition hover:opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue"
        >
          <Image
            src="/badges/app-store.svg"
            alt="Download on the App Store"
            width={w}
            height={h}
            className="h-auto"
          />
        </a>
      )}
    </div>
  );
}

/**
 * A one-line prompt with the badges beside it.
 *
 * Used where the page is already saying something else and the app is an
 * aside — under the booking form, at the end of a results page.
 */
export function GetAppRow({
  label = 'Get the Gora Taxi app',
  className = '',
}: {
  label?: string;
  className?: string;
}) {
  const t = useSiteText();
  if (!t('company.playStoreUrl') && !t('company.appStoreUrl')) return null;

  return (
    <div
      className={`flex flex-col items-center justify-center gap-3 sm:flex-row sm:gap-5 ${className}`}
    >
      <p className="text-[14px] font-semibold text-muted">{label}</p>
      <StoreBadges size="sm" className="justify-center" />
    </div>
  );
}

/**
 * The boxed version: a heading, a sentence and the badges.
 *
 * For a page that has nothing else to say at that point — the confirmation
 * screen, the support page — where the app is the next useful step rather
 * than a footnote.
 */
export function GetAppCard({
  title = 'Follow your trip in the app',
  body,
  className = '',
}: {
  title?: string;
  body?: string;
  className?: string;
}) {
  const t = useSiteText();
  if (!t('company.playStoreUrl') && !t('company.appStoreUrl')) return null;

  return (
    <div className={`card p-6 text-center sm:p-7 ${className}`}>
      <h2 className="font-display text-[19px] font-bold text-ink">{title}</h2>
      <p className="mx-auto mt-2 max-w-readable text-[15px] leading-relaxed text-muted">
        {body ||
          t('footer.appNote') ||
          'Open it with the same mobile number you booked with and your trip is already there.'}
      </p>
      <StoreBadges size="md" className="mt-5 justify-center" />
    </div>
  );
}
