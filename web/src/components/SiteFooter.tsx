'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { Mail, MessageCircle, Phone } from 'lucide-react';
import { apiGet } from '@/lib/api';
import { COMPANY } from '@/lib/company';
import type { PlatformSettings, SupportContact } from '@/lib/types';

/**
 * The footer carries the contact details, so it reads them the way the
 * contact section does: from the operator's settings, never written into
 * this file. Both queries share their keys with the home page, so on the
 * landing page they cost nothing — React Query serves what is already there.
 *
 * Every line is conditional. A number the operator has not configured leaves
 * no empty row behind.
 */
export function SiteFooter() {
  const { data: contact } = useQuery({
    queryKey: ['support-contact'],
    queryFn: () => apiGet<SupportContact>('/settings/support-contact'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });
  const { data: settings } = useQuery({
    queryKey: ['public-settings'],
    queryFn: () => apiGet<PlatformSettings>('/settings'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });

  const phone = (contact?.phone || settings?.supportPhone || '').trim();
  const email = (settings?.supportEmail || '').trim();
  const waDigits = (contact?.whatsapp || settings?.supportWhatsapp || '').replace(/\D/g, '');
  const whatsapp = waDigits ? (waDigits.length === 10 ? `91${waDigits}` : waDigits) : '';

  const row = 'flex items-center gap-2 py-1.5 text-sm text-muted transition hover:text-brand-600';

  return (
    <footer className="border-t border-hairline bg-surface">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 pb-10 pt-14 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/gora-logo.png" alt={COMPANY.brand} className="h-12 w-auto" />
          <p className="mt-2 text-xs font-semibold text-brand-600">India Ka Apna App</p>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Outstation cabs, local packages, drivers for your own car, and shared rides across India.
          </p>
          <p className="mt-4 text-xs leading-relaxed text-muted">{COMPANY.address}</p>
        </div>

        <div>
          <p className="text-sm font-bold text-ink">Book</p>
          <ul className="mt-2 space-y-1 text-sm text-muted">
            <li><Link href="/book/cab" className="inline-block py-1.5 hover:text-brand-600">Cab Booking</Link></li>
            <li><Link href="/book/hire_driver" className="inline-block py-1.5 hover:text-brand-600">Hire a Driver</Link></li>
            <li><Link href="/pool" className="inline-block py-1.5 hover:text-brand-600">Car Pool</Link></li>
          </ul>
        </div>

        <div>
          <p className="text-sm font-bold text-ink">Company</p>
          <ul className="mt-2 space-y-1 text-sm text-muted">
            <li><Link href="/#about" className="inline-block py-1.5 hover:text-brand-600">About us</Link></li>
            <li><Link href="/#cities" className="inline-block py-1.5 hover:text-brand-600">Where we run</Link></li>
            <li><Link href="/#contact" className="inline-block py-1.5 hover:text-brand-600">Contact</Link></li>
            <li><Link href="/support" className="inline-block py-1.5 hover:text-brand-600">Help &amp; Support</Link></li>
          </ul>
        </div>

        <div>
          <p className="text-sm font-bold text-ink">Reach us</p>
          <div className="mt-2">
            {phone && (
              <a href={`tel:${phone}`} className={row}>
                <Phone className="h-4 w-4 shrink-0 text-brand-500" />
                <span className="numeral">{phone}</span>
              </a>
            )}
            {whatsapp && (
              <a href={`https://wa.me/${whatsapp}`} target="_blank" rel="noreferrer" className={row}>
                <MessageCircle className="h-4 w-4 shrink-0 text-brand-500" />
                WhatsApp
              </a>
            )}
            {email && (
              <a href={`mailto:${email}`} className={row}>
                <Mail className="h-4 w-4 shrink-0 text-brand-500" />
                <span className="break-all">{email}</span>
              </a>
            )}
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Booked here? Open the {COMPANY.brand} app with the same mobile number and your trip is
            already waiting for you.
          </p>
          {/* The same caution the app shows above every booking feed. */}
          <p className="mt-4 rounded-lg bg-dangerbg px-3 py-2 text-[11px] font-semibold leading-snug text-dangerfg">
            Caution: never make advance payments to an unknown person without a reference.
          </p>
        </div>
      </div>

      <div className="border-t border-hairline px-4 py-4 text-center text-xs leading-relaxed text-muted">
        © {new Date().getFullYear()} {COMPANY.legalName}. All rights reserved.
        <span className="mx-2 hidden sm:inline">·</span>
        <span className="block sm:inline">
          GSTIN <span className="numeral">{COMPANY.gstin}</span>
        </span>
      </div>
    </footer>
  );
}
