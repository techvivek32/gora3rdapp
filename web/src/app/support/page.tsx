'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { MessageCircle, Phone, Smartphone } from 'lucide-react';
import { apiGet } from '@/lib/api';
import { useSiteText } from '@/lib/site-text';

interface SupportContact {
  phone?: string;
  whatsapp?: string;
}

/**
 * Help, for a visitor with no account.
 *
 * Raising a tracked complaint belongs to a real customer record, so that stays
 * in the app. Here we show the ways to reach a human, which is what someone
 * with a problem actually wants.
 *
 * Every word on it is the operator's. The numbers already came from their
 * settings; the copy was written into this file, so changing "24×7" meant a
 * developer and a deploy. It now comes from the same place — see
 * lib/site-text.ts for the defaults this falls back to.
 */
export default function SupportPage() {
  const t = useSiteText();
  const { data } = useQuery({
    queryKey: ['support-contact'],
    queryFn: () => apiGet<SupportContact>('/settings/support-contact'),
    retry: 0,
  });

  const phone = data?.phone?.trim();
  const whatsapp = data?.whatsapp?.trim().replace(/\D/g, '');

  return (
    <div className="mx-auto max-w-2xl px-4 py-12">
      <h1 className="display-lg">{t('support.title')}</h1>
      <p className="mt-1 text-sm text-muted">{t('support.subtitle')}</p>

      <div className="mt-6 space-y-3">
        {phone && (
          <a href={`tel:${phone}`} className="card flex items-center gap-4 p-5 transition hover:-translate-y-0.5 hover:shadow-lg">
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-emerald-50 text-ok">
              <Phone className="h-5 w-5" />
            </span>
            <span>
              <span className="block text-sm font-bold text-ink">Call us</span>
              <span className="block text-sm text-muted">{phone}</span>
            </span>
          </a>
        )}

        {whatsapp && (
          <a
            href={`https://wa.me/${whatsapp.length === 10 ? `91${whatsapp}` : whatsapp}`}
            target="_blank"
            rel="noreferrer"
            className="card flex items-center gap-4 p-5 transition hover:-translate-y-0.5 hover:shadow-lg"
          >
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-emerald-50 text-[#25D366]">
              <MessageCircle className="h-5 w-5" />
            </span>
            <span>
              <span className="block text-sm font-bold text-ink">WhatsApp</span>
              <span className="block text-sm text-muted">Chat with our team</span>
            </span>
          </a>
        )}
      </div>

      {/* Each block disappears if the operator empties it — a caution they
          no longer want to show should go, not leave a stripe of colour with
          nothing in it. */}
      {(t('support.bookingTitle') || t('support.bookingBody')) && (
        <div className="card mt-6 p-5">
          {t('support.bookingTitle') && (
            <h2 className="text-sm font-extrabold text-ink">{t('support.bookingTitle')}</h2>
          )}
          {t('support.bookingBody') && (
            <p className="mt-2 flex items-start gap-2 text-sm leading-relaxed text-muted">
              <Smartphone className="mt-0.5 h-4 w-4 shrink-0 text-brand-500" />
              {t('support.bookingBody')}
            </p>
          )}
        </div>
      )}

      {t('support.caution') && (
        <p className="mt-8 rounded-lg bg-dangerbg px-4 py-3 text-xs font-semibold leading-relaxed text-dangerfg">
          {t('support.caution')}
        </p>
      )}

      {t('support.cta') && (
        <div className="mt-8 text-center">
          <Link href="/book/cab" className="btn-primary px-6 py-3">
            {t('support.cta')}
          </Link>
        </div>
      )}
    </div>
  );
}
