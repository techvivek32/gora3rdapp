'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Building2, CreditCard, Landmark, MapPin, ShieldCheck, Mail, Phone, User, KeyRound, Eye, EyeOff, Pencil } from 'lucide-react';
import toast from 'react-hot-toast';
import { FRANCHISE_DOCS, type Franchise } from '@/components/franchises/FranchiseFormModal';
import { FranchiseEarnings } from '@/components/franchises/FranchiseEarnings';
import { useRole } from '@/hooks/useRole';

// One /profile route serves both panels: a franchise sees its franchise profile,
// an admin/super-admin sees their own account details.
export default function ProfilePage() {
  const { isFranchise } = useRole();
  return isFranchise ? <FranchiseProfile /> : <AdminProfile />;
}

// ─── Admin / super-admin own profile ─────────────────────────────────────────
function AdminProfile() {
  const { role } = useRole();
  const qc = useQueryClient();
  const { data: raw, isLoading } = useQuery({
    queryKey: ['admin-me'],
    queryFn: () => adminApi.getAdminProfile(),
  });
  const u: any = (raw as any)?.data;

  // Inline edit for the three self-service fields the admin may change.
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState({ fullName: '', email: '', mobile: '' });
  const save = useMutation({
    mutationFn: () => adminApi.updateAdminProfile(form),
    onSuccess: () => { toast.success('Profile updated'); qc.invalidateQueries({ queryKey: ['admin-me'] }); setEditing(false); },
    onError: (e: any) => toast.error(e?.message || 'Could not update profile'),
  });
  const startEdit = () => { setForm({ fullName: u?.fullName || '', email: u?.email || '', mobile: u?.mobile || '' }); setEditing(true); };

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>;
  if (!u) return <p className="p-6 text-sm text-gray-500">Profile not available.</p>;

  const roleLabel = u.role === 'super_admin' ? 'Super Admin' : u.role === 'admin' ? 'Admin' : (role || 'User');
  const joined = u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-2">
        <ShieldCheck className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">My Profile</h1>
          <p className="text-sm text-gray-500">Your account details.</p>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-orange-500/10 flex items-center justify-center shrink-0 overflow-hidden">
            {u.profileImage ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={u.profileImage} alt={u.fullName || 'Admin'} className="w-full h-full object-cover" />
            ) : (
              <span className="text-xl font-bold text-orange-500">{(u.fullName || u.email || 'A')[0]?.toUpperCase()}</span>
            )}
          </div>
          <div>
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">{u.fullName || '—'}</h2>
            <p className="text-sm text-gray-500">{u.email || '—'}</p>
          </div>
          <div className="ml-auto flex items-center gap-2">
            {!editing && (
              <button onClick={startEdit} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800">
                <Pencil className="w-4 h-4" /> Edit
              </button>
            )}
            <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium bg-orange-500/15 text-orange-500">
              <ShieldCheck className="w-3.5 h-3.5" /> {roleLabel}
            </span>
          </div>
        </div>

        {editing ? (
          <div className="mt-6 space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Field label="Full Name" value={form.fullName} onChange={(v) => setForm({ ...form, fullName: v })} />
              <Field label="Email" type="email" value={form.email} onChange={(v) => setForm({ ...form, email: v })} />
              <Field label="Mobile" value={form.mobile} onChange={(v) => setForm({ ...form, mobile: v })} />
            </div>
            <div className="flex gap-2">
              <button onClick={() => save.mutate()} disabled={save.isPending || !form.fullName.trim()} className="px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white text-sm font-semibold">
                {save.isPending ? 'Saving…' : 'Save Changes'}
              </button>
              <button onClick={() => setEditing(false)} className="px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium">Cancel</button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mt-6">
            <Info label="Full Name" value={u.fullName || '—'} icon={<User className="w-3.5 h-3.5" />} />
            <Info label="Email" value={u.email || '—'} icon={<Mail className="w-3.5 h-3.5" />} />
            <Info label="Mobile" value={u.mobile || '—'} mono icon={<Phone className="w-3.5 h-3.5" />} />
            <Info label="Role" value={roleLabel} />
            <Info label="City" value={u.city || '—'} />
            <Info label="Member Since" value={joined} />
          </div>
        )}
      </div>

      <ChangePasswordCard />
    </div>
  );
}

// ─── Change password (collapsed until opened; verify current, then set new) ───
function ChangePasswordCard() {
  const [open, setOpen] = useState(false);
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [show, setShow] = useState({ old: false, next: false, confirm: false });

  const reset = () => {
    setOldPassword(''); setNewPassword(''); setConfirm('');
    setShow({ old: false, next: false, confirm: false });
  };

  const mutation = useMutation({
    mutationFn: () => adminApi.changeAdminPassword({ oldPassword, newPassword }),
    onSuccess: () => {
      toast.success('Password changed successfully');
      reset();
      setOpen(false);
    },
    onError: (e: any) => toast.error(e?.message || 'Could not change password'),
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!oldPassword || !newPassword) return toast.error('Enter your current and new password');
    if (newPassword.length < 6) return toast.error('New password must be at least 6 characters');
    if (newPassword !== confirm) return toast.error('New passwords do not match');
    if (oldPassword === newPassword) return toast.error('New password must be different from the current one');
    mutation.mutate();
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <KeyRound className="w-5 h-5 text-orange-500" />
          <div>
            <h2 className="font-semibold text-gray-900 dark:text-white">Change Password</h2>
            {!open && <p className="text-xs text-gray-500">Update your account password.</p>}
          </div>
        </div>
        <button
          type="button"
          onClick={() => { if (open) reset(); setOpen((o) => !o); }}
          className={`inline-flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold ${
            open
              ? 'border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
              : 'bg-orange-500 hover:bg-orange-600 text-white'
          }`}
        >
          {open ? 'Cancel' : (<><KeyRound className="w-4 h-4" /> Change Password</>)}
        </button>
      </div>

      {open && (
        <form onSubmit={submit} className="mt-5 space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <PasswordField
              label="Current Password"
              value={oldPassword}
              onChange={setOldPassword}
              visible={show.old}
              onToggle={() => setShow((s) => ({ ...s, old: !s.old }))}
            />
            <PasswordField
              label="New Password"
              value={newPassword}
              onChange={setNewPassword}
              visible={show.next}
              onToggle={() => setShow((s) => ({ ...s, next: !s.next }))}
              hint="At least 6 characters"
            />
            <PasswordField
              label="Confirm New Password"
              value={confirm}
              onChange={setConfirm}
              visible={show.confirm}
              onToggle={() => setShow((s) => ({ ...s, confirm: !s.confirm }))}
            />
          </div>
          <button
            type="submit"
            disabled={mutation.isPending}
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white text-sm font-semibold"
          >
            <KeyRound className="w-4 h-4" /> {mutation.isPending ? 'Updating…' : 'Update Password'}
          </button>
        </form>
      )}
    </div>
  );
}

function PasswordField({
  label, value, onChange, visible, onToggle, hint,
}: {
  label: string; value: string; onChange: (v: string) => void; visible: boolean; onToggle: () => void; hint?: string;
}) {
  return (
    <div>
      <label className="block text-xs text-gray-400 mb-1">{label}</label>
      <div className="relative">
        <input
          type={visible ? 'text' : 'password'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          autoComplete="off"
          className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg pl-3 pr-10 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
        />
        <button
          type="button"
          onClick={onToggle}
          className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          tabIndex={-1}
        >
          {visible ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
        </button>
      </div>
      {hint && <p className="text-xs text-gray-400 mt-1">{hint}</p>}
    </div>
  );
}

// Read-only profile of the logged-in franchise. Editing is done by the admin
// from the admin panel — a franchise cannot change its own commission/documents.
function FranchiseProfile() {
  const { data: raw, isLoading } = useQuery({
    queryKey: ['franchise-me'],
    queryFn: () => adminApi.getFranchiseMe(),
  });
  const f: Franchise | undefined = (raw as any)?.data;

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>;
  if (!f) return <p className="p-6 text-sm text-gray-500">Profile not available.</p>;

  const dob = f.dob ? new Date(f.dob).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-2">
        <Building2 className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">My Profile</h1>
          <p className="text-sm text-gray-500">Your franchise account details.</p>
        </div>
      </div>

      {/* Summary */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-orange-500/10 flex items-center justify-center shrink-0">
            <Building2 className="w-7 h-7 text-orange-500" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">{f.name}</h2>
            <p className="text-sm text-gray-500">{f.agencyName || '—'}</p>
          </div>
          {f.city && (
            <span className="ml-auto inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium bg-orange-500/15 text-orange-500">
              <MapPin className="w-3.5 h-3.5" /> {f.city}
            </span>
          )}
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mt-6">
          <Info label="Phone" value={f.phone} mono />
          <Info label="Email" value={f.email || '—'} />
          <Info label="Date of Birth" value={dob} />
          <Info label="Cities" value={((f as any).cities?.length ? (f as any).cities : (f.city ? [f.city] : [])).join(', ') || '—'} />
          <Info label="Whole States" value={((f as any).states?.length ? (f as any).states : (f.state ? [f.state] : [])).join(', ') || '—'} />
          <Info label="Commission" value={`${f.commissionPercent ?? 0}%`} />
        </div>
      </div>

      {/* Documents */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Documents</h2>
        {(() => {
          const docs = f.documents ?? {};
          const has = FRANCHISE_DOCS.some((d) => docs[d.key]?.number || docs[d.key]?.frontImage || docs[d.key]?.backImage);
          if (!has) return <p className="text-sm text-gray-400">No documents on file.</p>;
          return (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {FRANCHISE_DOCS.map(({ key, label }) => {
                const d = docs[key];
                if (!d || (!d.number && !d.frontImage && !d.backImage)) return null;
                return (
                  <div key={key} className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
                    <div className="px-3 py-2 bg-gray-50 dark:bg-gray-800 flex items-center justify-between">
                      <span className="text-sm font-medium">{label}</span>
                      {d.number && <span className="font-mono text-xs text-gray-500">{d.number}</span>}
                    </div>
                    <div className="p-2 space-y-2">
                      <DocSide label="Front" src={d.frontImage} />
                      <DocSide label="Back" src={d.backImage} />
                    </div>
                  </div>
                );
              })}
            </div>
          );
        })()}
      </div>

      {/* Payout accounts */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Payout Accounts</h2>
        {(f.payoutAccounts?.length ?? 0) === 0 ? (
          <p className="text-sm text-gray-400">No payout accounts.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {f.payoutAccounts!.map((p, i) => (
              <div key={i} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-2">
                  {p.type === 'upi' ? <CreditCard className="w-4 h-4 text-orange-500" /> : <Landmark className="w-4 h-4 text-blue-500" />}
                  <span className="text-xs font-bold uppercase text-gray-500">{p.type}</span>
                  {p.label && <span className="text-sm font-medium text-gray-900 dark:text-white">· {p.label}</span>}
                </div>
                {p.type === 'upi' ? (
                  <div className="text-sm space-y-1">
                    <Row label="UPI ID" value={p.upiId} mono />
                    <Row label="Holder" value={p.accountHolderName} />
                  </div>
                ) : (
                  <div className="text-sm space-y-1">
                    <Row label="Bank" value={p.bankName} />
                    <Row label="Holder" value={p.accountHolderName} />
                    <Row label="Account" value={p.accountNumber} mono />
                    <Row label="IFSC" value={p.ifsc} mono />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* The franchise's own commission earnings + settlement history (read-only). */}
      <FranchiseEarnings self />
    </div>
  );
}

function Info({ label, value, mono, icon }: { label: string; value: string; mono?: boolean; icon?: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs text-gray-400 flex items-center gap-1">{icon}{label}</p>
      <p className={`text-sm text-gray-900 dark:text-white ${mono ? 'font-mono' : ''}`}>{value}</p>
    </div>
  );
}

function Field({ label, value, onChange, type = 'text' }: { label: string; value: string; onChange: (v: string) => void; type?: string }) {
  return (
    <div>
      <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
      />
    </div>
  );
}

function Row({ label, value, mono }: { label: string; value?: string; mono?: boolean }) {
  return (
    <div className="flex justify-between gap-2">
      <span className="text-gray-400">{label}</span>
      <span className={`text-gray-900 dark:text-white text-right ${mono ? 'font-mono' : ''}`}>{value || '—'}</span>
    </div>
  );
}

function DocSide({ label, src }: { label: string; src?: string }) {
  return (
    <div>
      <p className="text-xs text-gray-400 mb-1">{label}</p>
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt={label} className="w-full h-28 object-cover rounded border border-gray-200 dark:border-gray-700" />
      ) : (
        <div className="w-full h-28 rounded border border-dashed border-gray-300 dark:border-gray-700 flex items-center justify-center text-xs text-gray-400">No image</div>
      )}
    </div>
  );
}
