'use client';

import { useEffect, useState } from 'react';
import { useSession } from 'next-auth/react';
import { Settings } from 'lucide-react';
import { adminApi } from '@/lib/api';

export default function SettingsPage() {
  const [rzKeyId, setRzKeyId] = useState('');
  const [rzKeySecret, setRzKeySecret] = useState('');
  const [rzSecretSet, setRzSecretSet] = useState(false);
  const [showSecret, setShowSecret] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  const [supportPhone, setSupportPhone] = useState('');
  const [supportPhone2, setSupportPhone2] = useState('');
  const [customerServicePhone, setCustomerServicePhone] = useState('');
  const [customerServiceWhatsapp, setCustomerServiceWhatsapp] = useState('');
  const [supportWhatsapp, setSupportWhatsapp] = useState('');
  const [supportEmail, setSupportEmail] = useState('');
  const [contactSaving, setContactSaving] = useState(false);
  const [contactSaved, setContactSaved] = useState(false);
  const [contactError, setContactError] = useState('');

  const [minDeposit, setMinDeposit] = useState('');
  const [minWithdrawal, setMinWithdrawal] = useState('');
  const [minTransfer, setMinTransfer] = useState('');
  const [walletSaving, setWalletSaving] = useState(false);
  const [walletSaved, setWalletSaved] = useState(false);
  const [walletError, setWalletError] = useState('');

  const [autoBookMins, setAutoBookMins] = useState('');
  const [waSaving, setWaSaving] = useState(false);
  const [waSaved, setWaSaved] = useState(false);
  const [waError, setWaError] = useState('');

  // Customer-booking acceptance: minimum wallet balance a Golden driver needs.
  const [minWalletToAccept, setMinWalletToAccept] = useState('');
  // Hours before pickup when driver↔customer phone numbers become visible.
  const [contactRevealHours, setContactRevealHours] = useState('');
  const [cbSaving, setCbSaving] = useState(false);
  const [cbSaved, setCbSaved] = useState(false);
  const [cbError, setCbError] = useState('');

  // Contact reveal saves on its own now, so it needs its own flags.
  const [crSaving, setCrSaving] = useState(false);
  const [crSaved, setCrSaved] = useState(false);
  const [crError, setCrError] = useState('');

  // RC / DigiLocker verification vendor
  const [vClientId, setVClientId] = useState('');
  const [vClientSecret, setVClientSecret] = useState('');
  const [vSecretSet, setVSecretSet] = useState(false);
  const [showVSecret, setShowVSecret] = useState(false);
  const [vSandbox, setVSandbox] = useState(true);
  const [vEnforce, setVEnforce] = useState(false);
  const [vSaving, setVSaving] = useState(false);
  const [vSaved, setVSaved] = useState(false);
  const [vError, setVError] = useState('');

  const [loading, setLoading] = useState(true);

  // Wait for the session before fetching. SessionSync feeds the access token to
  // the axios client from useSession(), which is null on the first render — firing
  // here on mount sent the request with no Authorization header and got a 401.
  const { status } = useSession();

  useEffect(() => {
    if (status === 'loading') return;

    adminApi.getAdminSettings()
      .then((data: any) => {
        const s = data?.data ?? data;
        setRzKeyId(s.razorpayKeyId ?? '');
        // The secret is never sent to the browser anymore — we only learn whether
        // one is configured. Leave the field blank; blank on save keeps the stored secret.
        setRzKeySecret('');
        setRzSecretSet(!!s.razorpayKeySecretSet);
        setSupportPhone(s.supportPhone ?? '');
        setSupportPhone2(s.supportPhone2 ?? '');
        setCustomerServicePhone(s.customerServicePhone ?? '');
        setCustomerServiceWhatsapp(s.customerServiceWhatsapp ?? '');
        setSupportWhatsapp(s.supportWhatsapp ?? '');
        setSupportEmail(s.supportEmail ?? '');
        setMinDeposit(String(s.minDeposit ?? 1));
        setMinWithdrawal(String(s.minWithdrawal ?? 1));
        setMinTransfer(String(s.minTransfer ?? 1));
        setAutoBookMins(String(s.whatsappAutoBookMinutes ?? 0));
        setMinWalletToAccept(String(s.minWalletToAccept ?? 0));
        setContactRevealHours(String(s.contactRevealHoursBeforePickup ?? 1));
        setVClientId(s.verifyClientId ?? '');
        setVClientSecret('');
        setVSecretSet(!!s.verifyClientSecretSet);
        setVSandbox(s.verifySandbox !== false);
        setVEnforce(!!s.verifyEnforceNameMatch);
      })
      .catch(() => setError('Failed to load settings'))
      .finally(() => setLoading(false));
  }, [status]);

  const handleSaveContact = async () => {
    if (!supportPhone.trim() && !supportWhatsapp.trim()) return setContactError('Enter at least one number');
    const email = supportEmail.trim();
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return setContactError('Enter a valid email address');
    setContactError('');
    setContactSaving(true);
    try {
      await adminApi.updateSettings({
        supportPhone: supportPhone.trim(),
        supportPhone2: supportPhone2.trim(),
        customerServicePhone: customerServicePhone.trim(),
        customerServiceWhatsapp: customerServiceWhatsapp.trim(),
        supportWhatsapp: supportWhatsapp.trim(),
        supportEmail: email,
      });
      setContactSaved(true);
      setTimeout(() => setContactSaved(false), 3000);
    } catch (e: any) {
      setContactError(e.message || 'Failed to save');
    } finally {
      setContactSaving(false);
    }
  };

  const handleSaveWallet = async () => {
    const dep = Math.round(Number(minDeposit));
    const wd = Math.round(Number(minWithdrawal));
    const tr = Math.round(Number(minTransfer));
    if ([dep, wd, tr].some((n) => !Number.isFinite(n) || n < 1)) {
      return setWalletError('Enter valid amounts (₹1 or more)');
    }
    setWalletError('');
    setWalletSaving(true);
    try {
      await adminApi.updateSettings({ minDeposit: dep, minWithdrawal: wd, minTransfer: tr });
      setWalletSaved(true);
      setTimeout(() => setWalletSaved(false), 3000);
    } catch (e: any) {
      setWalletError(e.message || 'Failed to save');
    } finally {
      setWalletSaving(false);
    }
  };

  const handleSaveAutoBook = async () => {
    const mins = Math.round(Number(autoBookMins));
    if (!Number.isFinite(mins) || mins < 0) return setWaError('Enter a valid number of minutes (0 to disable)');
    setWaError('');
    setWaSaving(true);
    try {
      await adminApi.updateSettings({ whatsappAutoBookMinutes: mins });
      setWaSaved(true);
      setTimeout(() => setWaSaved(false), 3000);
    } catch (e: any) {
      setWaError(e.message || 'Failed to save');
    } finally {
      setWaSaving(false);
    }
  };

  const handleSaveMinWallet = async () => {
    const minW = Math.round(Number(minWalletToAccept));
    if (!Number.isFinite(minW) || minW < 0) return setCbError('Enter a valid amount (0 = no minimum)');
    setCbError('');
    setCbSaving(true);
    try {
      await adminApi.updateSettings({ minWalletToAccept: minW });
      setCbSaved(true);
      setTimeout(() => setCbSaved(false), 3000);
    } catch (e: any) {
      setCbError(e.message || 'Failed to save');
    } finally {
      setCbSaving(false);
    }
  };

  const handleSaveContactReveal = async () => {
    const revealH = Math.round(Number(contactRevealHours));
    if (!Number.isFinite(revealH) || revealH < 0) return setCrError('Enter valid hours (0 = show immediately)');
    setCrError('');
    setCrSaving(true);
    try {
      await adminApi.updateSettings({ contactRevealHoursBeforePickup: revealH });
      setCrSaved(true);
      setTimeout(() => setCrSaved(false), 3000);
    } catch (e: any) {
      setCrError(e.message || 'Failed to save');
    } finally {
      setCrSaving(false);
    }
  };

  const handleSaveVerification = async () => {
    setVError('');
    setVSaving(true);
    try {
      await adminApi.updateSettings({
        verifyClientId: vClientId.trim(),
        // Blank means "keep what is stored" — the server drops an empty secret.
        ...(vClientSecret.trim() ? { verifyClientSecret: vClientSecret.trim() } : {}),
        verifySandbox: vSandbox,
        verifyEnforceNameMatch: vEnforce,
      });
      if (vClientSecret.trim()) setVSecretSet(true);
      setVClientSecret('');
      setVSaved(true);
      setTimeout(() => setVSaved(false), 3000);
    } catch (e: any) {
      setVError(e.message || 'Failed to save');
    } finally {
      setVSaving(false);
    }
  };

  const handleSaveRazorpay = async () => {
    if (!rzKeyId.trim()) return setError('Key ID is required');
    // Secret only required if none is configured yet; blank keeps the existing one.
    if (!rzSecretSet && !rzKeySecret.trim()) return setError('Key Secret is required');
    setError('');
    setSaving(true);
    try {
      await adminApi.updateSettings({
        razorpayKeyId: rzKeyId.trim(),
        // Send the secret only when the admin actually typed a new one.
        ...(rzKeySecret.trim() ? { razorpayKeySecret: rzKeySecret.trim() } : {}),
      });
      if (rzKeySecret.trim()) setRzSecretSet(true);
      setRzKeySecret('');
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e: any) {
      setError(e.message || 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Settings className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Settings</h1>
          <p className="text-sm text-gray-500">Payment gateway & support configuration</p>
        </div>
      </div>

      {/* Two columns, each stacking its own cards: a flowing grid left a long gap
          beside the tall contact card. */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">

        <div className="space-y-4">
          {/* Support Contact Numbers */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Contact Us Details</h2>
            <p className="text-gray-500 text-sm mb-5">
              Support numbers for the <strong>partner app</strong> (drivers &amp; vendors), also shown on its
              About Us page. Where a city has a franchise with its own number, partners in that city reach
              the franchise instead. The customer app uses the separate number at the bottom.
            </p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Phone Number (for calls)</label>
                  <input
                    type="text"
                    value={supportPhone}
                    onChange={(e) => { setSupportPhone(e.target.value); setContactSaved(false); }}
                    placeholder="+919587090620"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Second Phone Number (fallback)</label>
                  <input
                    type="text"
                    value={supportPhone2}
                    onChange={(e) => { setSupportPhone2(e.target.value); setContactSaved(false); }}
                    placeholder="+91xxxxxxxxxx"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">Shown on About Us so users can call this if the first line is busy.</p>
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">WhatsApp Number</label>
                  <input
                    type="text"
                    value={supportWhatsapp}
                    onChange={(e) => { setSupportWhatsapp(e.target.value); setContactSaved(false); }}
                    placeholder="+919587090620"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">Include country code e.g. +91xxxxxxxxxx</p>
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Support Email</label>
                  <input
                    type="email"
                    value={supportEmail}
                    onChange={(e) => { setSupportEmail(e.target.value); setContactSaved(false); }}
                    placeholder="support@goracabs.com"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">Shown with the phone number on the app&apos;s About Us page.</p>
                </div>

                <div className="pt-2 border-t border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-600 dark:text-gray-400 mb-3">Customer app</p>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Customer Service Number</label>
                  <input
                    type="text"
                    value={customerServicePhone}
                    onChange={(e) => { setCustomerServicePhone(e.target.value); setContactSaved(false); }}
                    placeholder="+91xxxxxxxxxx"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">
                    Called by customers from the app &mdash; the &ldquo;Your Travel Expert&rdquo; card, help and
                    About Us. One number for every customer in every city; a franchise never replaces it.
                    Leave blank to use the partner number above.
                  </p>
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Customer WhatsApp Number</label>
                  <input
                    type="text"
                    value={customerServiceWhatsapp}
                    onChange={(e) => { setCustomerServiceWhatsapp(e.target.value); setContactSaved(false); }}
                    placeholder="+91xxxxxxxxxx"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">Leave blank to use the customer service number above.</p>
                </div>
                {contactError && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{contactError}</p>}
                <button
                  onClick={handleSaveContact}
                  disabled={contactSaving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {contactSaving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : contactSaved ? '✓ Saved!' : 'Save Contact Details'}
                </button>
              </div>
            )}
          </div>

          {/* Contact number reveal */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Contact Numbers — When to Reveal</h2>
            <p className="text-gray-500 text-sm mb-5">
              When the driver and the customer get to see each other&apos;s phone number on a confirmed booking.
            </p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Hours before pickup</label>
                  <input
                    type="number" min={0}
                    value={contactRevealHours}
                    onChange={(e) => { setContactRevealHours(e.target.value); setCrSaved(false); }}
                    placeholder="e.g. 1 (0 = show immediately)"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">
                    Applies to one-way, round-trip &amp; local bookings. The same window also gates
                    &ldquo;Open Trip &amp; Navigate&rdquo;. <strong>0 = show as soon as the booking is confirmed.</strong>
                  </p>
                </div>
                {crError && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{crError}</p>}
                <button
                  onClick={handleSaveContactReveal}
                  disabled={crSaving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {crSaving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : crSaved ? '✓ Saved!' : 'Save Contact Reveal'}
                </button>
              </div>
            )}
          </div>

          {/* WhatsApp Bookings */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">WhatsApp Bookings</h2>
            <p className="text-gray-500 text-sm mb-5">Auto-mark a WhatsApp booking as &quot;Booked&quot; this many minutes after it is posted. Only WhatsApp posts are affected.</p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Auto-book after (minutes)</label>
                  <input
                    type="number"
                    min={0}
                    value={autoBookMins}
                    onChange={(e) => { setAutoBookMins(e.target.value); setWaSaved(false); }}
                    placeholder="10"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">Set 0 to disable auto-booking. E.g. 10 = a WhatsApp booking becomes Booked 10 minutes after posting.</p>
                </div>
                {waError && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{waError}</p>}
                <button
                  onClick={handleSaveAutoBook}
                  disabled={waSaving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {waSaving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : waSaved ? '✓ Saved!' : 'Save WhatsApp Settings'}
                </button>
              </div>
            )}
          </div>
        </div>

        <div className="space-y-4">
          {/* Wallet Limits */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Wallet Limits</h2>
            <p className="text-gray-500 text-sm mb-5">Minimum amounts (₹) a user must enter in the app to add money, withdraw, or transfer.</p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Minimum Deposit (Add Money)</label>
                  <input
                    type="number"
                    min={1}
                    value={minDeposit}
                    onChange={(e) => { setMinDeposit(e.target.value); setWalletSaved(false); }}
                    placeholder="100"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Minimum Withdrawal</label>
                  <input
                    type="number"
                    min={1}
                    value={minWithdrawal}
                    onChange={(e) => { setMinWithdrawal(e.target.value); setWalletSaved(false); }}
                    placeholder="500"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Minimum Transfer</label>
                  <input
                    type="number"
                    min={1}
                    value={minTransfer}
                    onChange={(e) => { setMinTransfer(e.target.value); setWalletSaved(false); }}
                    placeholder="100"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">These limits are enforced by the app and the server.</p>
                </div>
                {walletError && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{walletError}</p>}
                <button
                  onClick={handleSaveWallet}
                  disabled={walletSaving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {walletSaving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : walletSaved ? '✓ Saved!' : 'Save Wallet Limits'}
                </button>
              </div>
            )}
          </div>

          {/* Razorpay Keys */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Razorpay Configuration</h2>
            <p className="text-gray-500 text-sm mb-5">Payment gateway credentials. Key Secret is cleared after saving for security.</p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Key ID</label>
                  <input
                    type="text"
                    value={rzKeyId}
                    onChange={(e) => { setRzKeyId(e.target.value); setSaved(false); }}
                    placeholder="rzp_live_xxxxxxxxxxxx"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Key Secret</label>
                  <div className="relative">
                    <input
                      type={showSecret ? 'text' : 'password'}
                      value={rzKeySecret}
                      onChange={(e) => { setRzKeySecret(e.target.value); setSaved(false); }}
                      placeholder={rzSecretSet ? '•••••••• configured — leave blank to keep' : 'Enter secret'}
                      className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 pr-16 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                    />
                    <button type="button" onClick={() => setShowSecret((v) => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-gray-600">
                      {showSecret ? 'Hide' : 'Show'}
                    </button>
                  </div>
                </div>
                {error && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{error}</p>}
                <button
                  onClick={handleSaveRazorpay}
                  disabled={saving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {saving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : saved ? '✓ Saved!' : 'Save Razorpay Keys'}
                </button>
              </div>
            )}
          </div>

          {/* Driver wallet requirement */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Driver — Minimum Wallet Balance</h2>
            <p className="text-gray-500 text-sm mb-5">
              How much a <strong>driver</strong> must hold in their wallet before a booking can reach them —
              whether they accept it themselves, or an admin or owner assigns it to them.
            </p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Minimum wallet balance (₹)</label>
                  <input
                    type="number" min={0}
                    value={minWalletToAccept}
                    onChange={(e) => { setMinWalletToAccept(e.target.value); setCbSaved(false); }}
                    placeholder="e.g. 500 (0 = no minimum)"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                  <p className="text-xs text-gray-400 mt-1">
                    Nothing is deducted — it is only an eligibility check. <strong>0 = no minimum.</strong>
                  </p>
                  <p className="text-xs text-gray-400 mt-2">
                    This acts as a <strong>floor</strong>. A partner booking already needs its own commission in the
                    driver&apos;s wallet, so the driver must have whichever is larger. e.g. commission ₹600 → ₹600 needed;
                    commission ₹300 with this set to ₹500 → ₹500 needed.
                  </p>
                </div>
                {cbError && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{cbError}</p>}
                <button
                  onClick={handleSaveMinWallet}
                  disabled={cbSaving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {cbSaving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : cbSaved ? '✓ Saved!' : 'Save Minimum Wallet'}
                </button>
              </div>
            )}
          </div>

          {/* RC / DigiLocker verification */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
            <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Vehicle &amp; Driver Verification</h2>
            <p className="text-gray-500 text-sm mb-5">
              Credentials for RC lookup and DigiLocker. With these set, adding a vehicle needs only the
              registration number — model, fuel, seats, colour and owner name come from the RC record.
              Leave blank to keep manual entry.
            </p>
            {loading ? (
              <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
                <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
                Loading...
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Client ID</label>
                  <input
                    type="text"
                    value={vClientId}
                    onChange={(e) => { setVClientId(e.target.value); setVSaved(false); }}
                    placeholder="CF1234567ABCDEFGH"
                    className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Client Secret</label>
                  <div className="relative">
                    <input
                      type={showVSecret ? 'text' : 'password'}
                      value={vClientSecret}
                      onChange={(e) => { setVClientSecret(e.target.value); setVSaved(false); }}
                      placeholder={vSecretSet ? '•••••••• configured — leave blank to keep' : 'Enter secret'}
                      className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 pr-16 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                    />
                    <button type="button" onClick={() => setShowVSecret((v) => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-gray-600">
                      {showVSecret ? 'Hide' : 'Show'}
                    </button>
                  </div>
                </div>
                <label className="flex items-start gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={vSandbox}
                    onChange={(e) => { setVSandbox(e.target.checked); setVSaved(false); }}
                    className="mt-0.5 accent-orange-500"
                  />
                  <span className="text-xs text-gray-600 dark:text-gray-400">
                    <span className="font-medium text-gray-900 dark:text-white">Sandbox mode</span> — test keys, test data.
                    Turn this off once live keys are in.
                  </span>
                </label>
                <label className="flex items-start gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={vEnforce}
                    onChange={(e) => { setVEnforce(e.target.checked); setVSaved(false); }}
                    className="mt-0.5 accent-orange-500"
                  />
                  <span className="text-xs text-gray-600 dark:text-gray-400">
                    <span className="font-medium text-gray-900 dark:text-white">Block name mismatch</span> — refuse a vehicle
                    whose RC owner name does not match the account. A lookup that cannot run is never
                    treated as a mismatch.
                  </span>
                </label>
                {vError && <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{vError}</p>}
                <button
                  onClick={handleSaveVerification}
                  disabled={vSaving}
                  className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                >
                  {vSaving ? <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</> : vSaved ? '✓ Saved!' : 'Save Verification Keys'}
                </button>
              </div>
            )}
          </div>
        </div>

      </div>
    </div>
  );
}
