'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { X, Plus, Minus, ArrowLeftRight, Search, CheckCircle2 } from 'lucide-react';
import toast from 'react-hot-toast';

/** The bits of a user this modal needs — shared by the Wallets list and the
 *  Wallet tab on the user-detail page. */
export interface AdjustWalletUser {
  _id: string;
  fullName: string;
  mobile: string;
  walletBalance: number;
}

interface Recipient {
  _id: string;
  fullName?: string;
  agencyName?: string;
  mobile: string;
  city?: string;
}

type Mode = 'credit' | 'debit' | 'transfer';

export function AdjustWalletModal({
  user,
  onClose,
  onDone,
}: {
  user: AdjustWalletUser;
  onClose: () => void;
  onDone: () => void;
}) {
  const [mode, setMode] = useState<Mode>('credit');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  // Transfer only.
  const [phone, setPhone] = useState('');
  const [recipient, setRecipient] = useState<Recipient | null>(null);
  const [lookupError, setLookupError] = useState('');
  const [looking, setLooking] = useState(false);

  const balance = user.walletBalance ?? 0;
  const amt = Number(amount);
  const isTransfer = mode === 'transfer';

  const lookup = async () => {
    const digits = phone.replace(/\D/g, '');
    if (digits.length < 10) return setLookupError('Enter a valid 10-digit number');
    setLooking(true);
    setLookupError('');
    setRecipient(null);
    try {
      const res: any = await adminApi.lookupUserByMobile(digits);
      const found = res?.data ?? res;
      if (!found?._id) throw new Error('No user found');
      if (found._id === user._id) {
        setLookupError("That's the same user — pick someone else.");
        return;
      }
      setRecipient(found);
    } catch (e: any) {
      setLookupError(e?.message || 'No user found with this number');
    } finally {
      setLooking(false);
    }
  };

  const mutation = useMutation({
    mutationFn: () =>
      isTransfer
        ? adminApi.transferWallet(user._id, {
            mobile: recipient!.mobile,
            amount: amt,
            note: reason.trim() || undefined,
          })
        : adminApi.adjustWallet(user._id, { amount: amt, type: mode, reason: reason.trim() }),
    onSuccess: (res: any) => {
      toast.success(res?.message || (isTransfer ? 'Funds transferred' : 'Wallet updated'));
      onDone();
    },
    onError: (e: any) => toast.error(e?.message || 'Could not update wallet'),
  });

  // A transfer and a debit both leave this wallet, so both are capped at the balance.
  const overBalance = (mode === 'debit' || isTransfer) && amt > balance;
  const valid =
    amt >= 1 &&
    !overBalance &&
    (isTransfer ? !!recipient : reason.trim().length > 0);

  const newBalance = Math.max(0, balance + (mode === 'credit' ? amt || 0 : -(amt || 0)));

  const tab = (m: Mode, label: string, icon: React.ReactNode, activeCls: string) => (
    <button
      type="button"
      onClick={() => { setMode(m); setLookupError(''); }}
      className={`flex items-center justify-center gap-1.5 py-2.5 rounded-lg border text-sm font-medium transition-colors ${
        mode === m ? activeCls : 'border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300'
      }`}
    >
      {icon} {label}
    </button>
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div
        className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Adjust Wallet</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-4 py-3">
            <div>
              <div className="font-medium text-sm">{user.fullName}</div>
              <div className="text-xs text-gray-500 font-mono">{user.mobile}</div>
            </div>
            <div className="text-right">
              <div className="text-xs text-gray-500">Current balance</div>
              <div className="font-bold text-gray-900 dark:text-white">₹{balance.toLocaleString('en-IN')}</div>
            </div>
          </div>

          {/* Credit / Debit / Transfer */}
          <div className="grid grid-cols-3 gap-2">
            {tab('credit', 'Add', <Plus className="w-4 h-4" />, 'bg-emerald-500 border-emerald-500 text-white')}
            {tab('debit', 'Cut', <Minus className="w-4 h-4" />, 'bg-red-500 border-red-500 text-white')}
            {tab('transfer', 'Transfer', <ArrowLeftRight className="w-4 h-4" />, 'bg-orange-500 border-orange-500 text-white')}
          </div>

          {/* Transfer: find the recipient by phone, exactly like the app does. */}
          {isTransfer && (
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Send to (mobile number)</label>
              <div className="flex gap-2">
                <Input
                  value={phone}
                  onChange={(e) => { setPhone(e.target.value); setRecipient(null); setLookupError(''); }}
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); lookup(); } }}
                  placeholder="10-digit number"
                  className="font-mono"
                />
                <Button variant="outline" onClick={lookup} isLoading={looking} disabled={!phone.trim()}>
                  <Search className="w-4 h-4" />
                </Button>
              </div>
              {lookupError && <p className="text-xs text-red-500 mt-1">{lookupError}</p>}
              {recipient && (
                <div className="mt-2 flex items-center gap-2 rounded-lg border border-emerald-500/40 bg-emerald-500/5 px-3 py-2">
                  <CheckCircle2 className="w-4 h-4 text-emerald-500 shrink-0" />
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-gray-900 dark:text-white truncate">
                      {recipient.agencyName || recipient.fullName}
                    </p>
                    <p className="text-xs text-gray-500 font-mono">
                      {recipient.mobile}{recipient.city ? ` · ${recipient.city}` : ''}
                    </p>
                  </div>
                </div>
              )}
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Amount (₹)</label>
            <Input
              type="number"
              min={1}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="e.g. 500"
            />
            {overBalance && (
              <p className="text-xs text-red-500 mt-1">Amount is more than the user&apos;s balance.</p>
            )}
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">
              {isTransfer ? 'Note (optional)' : 'Reason (shown to the user)'}
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={isTransfer ? 120 : 200}
              rows={3}
              placeholder={
                isTransfer
                  ? 'e.g. For the Jaipur trip'
                  : mode === 'credit'
                    ? 'e.g. Refund for cancelled ride'
                    : 'e.g. Penalty for fake requirement'
              }
              className="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-transparent px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
          </div>

          <div className="rounded-lg bg-gray-50 dark:bg-gray-800 px-4 py-2.5 text-sm">
            {isTransfer ? (
              <>
                Sending{' '}
                <span className="font-bold">₹{(amt || 0).toLocaleString('en-IN')}</span>
                {recipient && <> to <span className="font-bold">{recipient.agencyName || recipient.fullName}</span></>}
                {' · '}
                <span className="text-gray-500">balance left: ₹{newBalance.toLocaleString('en-IN')}</span>
              </>
            ) : (
              <>New balance: <span className="font-bold">₹{newBalance.toLocaleString('en-IN')}</span></>
            )}
          </div>
        </div>

        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button
            variant={mode === 'debit' ? 'destructive' : 'default'}
            disabled={!valid}
            isLoading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {mode === 'credit' ? 'Add money' : mode === 'debit' ? 'Cut money' : 'Transfer'}
          </Button>
        </div>
      </div>
    </div>
  );
}
