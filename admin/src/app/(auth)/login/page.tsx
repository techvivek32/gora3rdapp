'use client';

import { useState } from 'react';
import { signIn } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import toast from 'react-hot-toast';
import { adminApi } from '@/lib/api';

const loginSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(6, 'Password too short'),
});

type LoginForm = z.infer<typeof loginSchema>;

const inputCls =
  'w-full px-4 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg text-sm ' +
  'focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent ' +
  'bg-white dark:bg-gray-800 text-gray-900 dark:text-white';
const primaryBtn =
  'w-full bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white font-semibold ' +
  'py-2.5 px-4 rounded-lg transition-colors duration-200 text-sm';

export default function LoginPage() {
  const [mode, setMode] = useState<'login' | 'forgot'>('login');

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-50 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl p-8">
          {/* Logo */}
          <div className="flex items-center justify-center mb-8">
            <div className="w-12 h-12 bg-orange-500 rounded-xl flex items-center justify-center mr-3">
              <span className="text-white font-bold text-xl">G</span>
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Gora Cabs</h1>
              <p className="text-sm text-gray-500">Admin Panel</p>
            </div>
          </div>

          {mode === 'login' ? (
            <LoginForm onForgot={() => setMode('forgot')} />
          ) : (
            <ForgotPassword onBack={() => setMode('login')} />
          )}

          <p className="mt-6 text-center text-xs text-gray-500">Gora Cabs Admin Panel v1.0.0</p>
        </div>
      </div>
    </div>
  );
}

function LoginForm({ onForgot }: { onForgot: () => void }) {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const { register, handleSubmit, formState: { errors } } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data: LoginForm) => {
    setIsLoading(true);
    try {
      const result = await signIn('credentials', {
        email: data.email,
        password: data.password,
        redirect: false,
      });
      if (result?.error) {
        toast.error('Invalid credentials');
      } else {
        toast.success('Welcome back!');
        router.push('/dashboard');
      }
    } catch {
      toast.error('Login failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200 mb-6 text-center">
        Sign in to continue
      </h2>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email Address</label>
          <input {...register('email')} type="email" placeholder="admin@goracabs.com" className={inputCls} />
          {errors.email && <p className="mt-1 text-xs text-red-500">{errors.email.message}</p>}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Password</label>
          <input {...register('password')} type="password" placeholder="••••••••" className={inputCls} />
          {errors.password && <p className="mt-1 text-xs text-red-500">{errors.password.message}</p>}
        </div>

        <div className="text-right -mt-1">
          <button type="button" onClick={onForgot} className="text-xs font-medium text-orange-600 hover:text-orange-700">
            Forgot password?
          </button>
        </div>

        <button type="submit" disabled={isLoading} className={primaryBtn}>
          {isLoading ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" className="opacity-25" />
                <path d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" fill="currentColor" className="opacity-75" />
              </svg>
              Signing in...
            </span>
          ) : 'Sign In'}
        </button>
      </form>
    </>
  );
}

// Admin/super-admin only: reset the password with a phone OTP. Regular users and
// franchises can't use this (the backend only issues an OTP for admin accounts).
function ForgotPassword({ onBack }: { onBack: () => void }) {
  const [step, setStep] = useState<1 | 2>(1);
  const [mobile, setMobile] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const sendOtp = async () => {
    if (!mobile.trim()) return toast.error('Enter your registered mobile number');
    setLoading(true);
    try {
      const res: any = await adminApi.adminForgotSendOtp(mobile.trim());
      toast.success(res?.message || 'OTP sent');
      setStep(2);
    } catch (e: any) {
      toast.error(e?.message || 'Could not send OTP');
    } finally {
      setLoading(false);
    }
  };

  const reset = async () => {
    if (!otp.trim()) return toast.error('Enter the OTP');
    if (newPassword.length < 6) return toast.error('New password must be at least 6 characters');
    setLoading(true);
    try {
      const res: any = await adminApi.adminForgotReset({ mobile: mobile.trim(), otp: otp.trim(), newPassword });
      toast.success(res?.message || 'Password reset successful');
      onBack();
    } catch (e: any) {
      toast.error(e?.message || 'Could not reset password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <h2 className="text-xl font-semibold text-gray-800 dark:text-gray-200 mb-1 text-center">Reset your password</h2>
      <p className="text-xs text-gray-500 text-center mb-6">
        Admin accounts only. We&apos;ll text a one-time code to your registered mobile number.
      </p>

      {step === 1 ? (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Mobile Number</label>
            <input
              value={mobile}
              onChange={(e) => setMobile(e.target.value)}
              placeholder="Registered admin mobile"
              className={inputCls}
              onKeyDown={(e) => e.key === 'Enter' && sendOtp()}
            />
          </div>
          <button onClick={sendOtp} disabled={loading} className={primaryBtn}>
            {loading ? 'Sending…' : 'Send OTP'}
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">OTP</label>
            <input
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              placeholder="6-digit code"
              inputMode="numeric"
              className={inputCls}
            />
            <p className="mt-1 text-xs text-gray-400">Sent to {mobile}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">New Password</label>
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="At least 6 characters"
              className={inputCls}
              onKeyDown={(e) => e.key === 'Enter' && reset()}
            />
          </div>
          <button onClick={reset} disabled={loading} className={primaryBtn}>
            {loading ? 'Saving…' : 'Reset Password'}
          </button>
          <button type="button" onClick={() => setStep(1)} className="w-full text-center text-xs text-gray-500 hover:text-gray-700">
            Change number / resend OTP
          </button>
        </div>
      )}

      <button type="button" onClick={onBack} className="mt-5 w-full text-center text-xs text-gray-500 hover:text-gray-700">
        ← Back to sign in
      </button>
    </>
  );
}
