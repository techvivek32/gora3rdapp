'use client';

import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Globe, Image as ImageIcon, Map, Type } from 'lucide-react';
import { WebsiteTextForm } from '@/components/WebsiteTextForm';
import { WebsiteHeroCard } from '@/components/WebsiteHeroCard';
import { ServiceCities } from '@/components/ServiceCities';

/**
 * Everything about the public website, in one place.
 *
 * It used to be three: the wording under "Website Text", the hero picture
 * buried in Home Content next to the APP's showcase cards, and the service
 * cities as a tab under Cities beside an analytics screen. Nothing told an
 * operator those three belonged together, so "change the website" meant
 * remembering where each piece lived.
 *
 * The pieces are the same components as before — only the way in changed, so
 * the old routes still work and still edit the same data.
 */
const TABS = [
  { key: 'text', label: 'Text & wording', icon: Type },
  { key: 'hero', label: 'Hero image', icon: ImageIcon },
  { key: 'cities', label: 'Service cities', icon: Map },
] as const;

type TabKey = (typeof TABS)[number]['key'];

const isTab = (v: string | null): v is TabKey => TABS.some((t) => t.key === v);

/** `useSearchParams` needs a Suspense boundary to prerender; this is it. */
export default function WebsitePage() {
  return (
    <Suspense fallback={null}>
      <WebsiteModule />
    </Suspense>
  );
}

function WebsiteModule() {
  const router = useRouter();
  const params = useSearchParams();
  const [tab, setTab] = useState<TabKey>('text');

  // The tab lives in the URL so a link can point at one ("…/website?tab=hero")
  // and a refresh does not throw you back to the first.
  useEffect(() => {
    const q = params.get('tab');
    if (isTab(q)) setTab(q);
  }, [params]);

  const go = (k: TabKey) => {
    setTab(k);
    router.replace(`/website?tab=${k}`, { scroll: false });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <span className="mt-0.5 grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-orange-500/10 text-orange-500">
          <Globe className="h-5 w-5" />
        </span>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Website</h1>
          <p className="mt-1 text-gray-500">
            Everything shown on the public site — the words, the hero picture and the cities you
            cover. Changes are live as soon as they are saved.
          </p>
        </div>
      </div>

      {/* Real tabs: `role="tab"` + `aria-selected`, not `aria-pressed`. A
          pressed-button tab is both wrong for a screen reader and ambiguous
          on the page — the colour swatches inside the Service cities form
          are aria-pressed buttons, and the tab was matching first. */}
      <div role="tablist" aria-label="Website sections" className="flex flex-wrap gap-1.5">
        {TABS.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            role="tab"
            onClick={() => go(key)}
            aria-selected={tab === key}
            className={`inline-flex items-center gap-2 rounded-lg border px-4 py-2 text-sm font-semibold transition-colors ${
              tab === key
                ? 'border-orange-500 bg-orange-500 text-white'
                : 'border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'
            }`}
          >
            <Icon className="h-4 w-4" />
            {label}
          </button>
        ))}
      </div>

      {tab === 'text' && <WebsiteTextForm />}
      {tab === 'hero' && <WebsiteHeroCard />}
      {tab === 'cities' && <ServiceCities />}
    </div>
  );
}
