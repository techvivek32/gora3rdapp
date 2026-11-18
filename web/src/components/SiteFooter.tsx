'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { Mail, MessageCircle, Phone } from 'lucide-react';
import { apiGet } from '@/lib/api';
import { useSiteText } from '@/lib/site-text';
import type { PlatformSettings, SupportContact } from '@/lib/types';

/**
 * The footer carries the contact details, so it reads them the way the
 * contact section does: from the operator's settings, never written into
 * this file. Both queries share their keys with the home page, so on the
 * landing page they cost nothing — React Query serves what is already there.
 *
 * Every line is conditional. A number the operator has not configured leaves
 * no empty row behind.
 *
 * Dark, with warm headings over cool grey links — the reference's footer, and
 * the one place a long white page needs a full stop. It is deliberately NOT
 * themed: a footer that goes white in light mode stops being a full stop.
 * Measured on this ground: the links are 11.8:1 and the headings 10.3:1.
 */
export function SiteFooter() {
  const t = useSiteText();
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

  const head = 'font-display text-[17px] font-bold text-[#FDBA74]';
  const link = 'inline-block py-1.5 text-[15px] text-[#D1D5DB] transition hover:text-white';
  const row = 'flex items-center gap-2.5 py-1.5 text-[15px] text-[#D1D5DB] transition hover:text-white';

  return (
    <footer className="bg-banddeep">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 pb-12 pt-16 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/gora-logo.png" alt={t('company.brand')} className="h-12 w-auto" />
          <p className="mt-3 text-[13px] font-semibold text-[#FDBA74]">{t('company.tagline')}</p>
          <p className="mt-4 text-[15px] leading-relaxed text-[#D1D5DB]">{t('footer.blurb')}</p>
          <p className="mt-4 text-[13px] leading-relaxed text-[#9CA3AF]">{t('company.address')}</p>
        </div>

        <div>
          <p className={head}>Book</p>
          <ul className="mt-3 space-y-0.5">
            <li><Link href="/book/cab" className={link}>Cab Booking</Link></li>
            <li><Link href="/book/hire_driver" className={link}>Hire a Driver</Link></li>
            <li><Link href="/pool" className={link}>Car Pool</Link></li>
          </ul>
        </div>

        <div>
          <p className={head}>Company</p>
          <ul className="mt-3 space-y-0.5">
            <li><Link href="/#about" className={link}>About us</Link></li>
            <li><Link href="/#cities" className={link}>Where we run</Link></li>
            <li><Link href="/#faq" className={link}>FAQ</Link></li>
            <li><Link href="/support" className={link}>Help &amp; Support</Link></li>
          </ul>
        </div>

        <div>
          <p className={head}>Reach us</p>
          <div className="mt-3">
            {phone && (
              <a href={`tel:${phone}`} className={row}>
                <Phone className="h-4 w-4 shrink-0 text-[#FDBA74]" />
                <span className="numeral">{phone}</span>
              </a>
            )}
            {whatsapp && (
              <a href={`https://wa.me/${whatsapp}`} target="_blank" rel="noreferrer" className={row}>
                <MessageCircle className="h-4 w-4 shrink-0 text-[#FDBA74]" />
                WhatsApp
              </a>
            )}
            {email && (
              <a href={`mailto:${email}`} className={row}>
                <Mail className="h-4 w-4 shrink-0 text-[#FDBA74]" />
                <span className="break-all">{email}</span>
              </a>
            )}
          </div>
          {t('footer.appNote') && (
            <p className="mt-3 text-[15px] leading-relaxed text-[#D1D5DB]">{t('footer.appNote')}</p>
          )}
          {/* The same caution the app shows above every booking feed. Empty
              means the operator took it down, so the box goes with it. */}
          {t('footer.caution') && (
            <p className="mt-4 rounded-xl bg-white/[0.07] px-3.5 py-2.5 text-[12px] font-semibold leading-snug text-[#FCA5A5]">
              {t('footer.caution')}
            </p>
          )}
        </div>
      </div>

      <div className="border-t border-white/10 px-4 py-5 text-center text-[13px] leading-relaxed text-[#9CA3AF]">
        © {new Date().getFullYear()} {t('company.legalName')}. All rights reserved.
        {t('company.gstin') && (
          <>
            <span className="mx-2 hidden sm:inline">·</span>
            <span className="block sm:inline">
              GSTIN <span className="numeral">{t('company.gstin')}</span>
            </span>
          </>
        )}
      </div>
    </footer>
  );
}
