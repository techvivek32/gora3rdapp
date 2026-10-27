'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { MessageCircle, Phone, Smartphone } from 'lucide-react';
import { apiGet } from '@/lib/api';

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
 */
export default function SupportPage() {
  const { data } = useQuery({
    queryKey: ['support-contact'],
    queryFn: () => apiGet<SupportContact>('/settings/support-contact'),
    retry: 0,
  });

  const phone = data?.phone?.trim();
  const whatsapp = data?.whatsapp?.trim().replace(/\D/g, '');

  return (
    <div className="mx-auto max-w-2xl px-4 py-12">
      <h1 className="text-2xl font-extrabold text-ink">Help &amp; Support</h1>
      <p className="mt-1 text-sm text-muted">We are here 24×7. Reach us whichever way suits you.</p>

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

      <div className="card mt-6 p-5">
        <h2 className="text-sm font-extrabold text-ink">About a booking you made here</h2>
        <p className="mt-2 flex items-start gap-2 text-sm leading-relaxed text-muted">
          <Smartphone className="mt-0.5 h-4 w-4 shrink-0 text-brand-500" />
          Keep your booking reference handy when you call. To see the trip, track the driver or raise a
          complaint, open the Gora Cabs app with the same mobile number you booked with — the booking is
          already there.
        </p>
      </div>

      <p className="mt-8 rounded-lg bg-rose-50 px-4 py-3 text-xs font-semibold leading-relaxed text-rose-700">
        Caution: never make advance payments to an unknown person without a reference. Pay only through
        this website or the Gora Cabs app.
      </p>

      <div className="mt-8 text-center">
        <Link href="/book/cab" className="btn-primary px-6 py-3">
          Book a cab
        </Link>
      </div>
    </div>
  );
}
