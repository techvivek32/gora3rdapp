import axios from 'axios';

const BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://backend.goracabs.com/api/v1';

const apiClient = axios.create({ baseURL: BASE_URL, timeout: 30000 });

// Kept in sync by SessionSync component (providers.tsx) via useSession()
let _authToken: string | null = null;
export const setAuthToken = (token: string | null) => { _authToken = token; };

apiClient.interceptors.request.use((config) => {
  if (_authToken) {
    config.headers.Authorization = `Bearer ${_authToken}`;
  }
  return config;
});

apiClient.interceptors.response.use(
  (res) => res.data,
  (error) => {
    const message = error.response?.data?.message || error.message || 'Something went wrong';
    return Promise.reject(new Error(message));
  },
);

export const adminApi = {
  // ─── Auth ──────────────────────────────────────────────────────────────────
  login: (data: { identifier: string; password: string }) =>
    apiClient.post('/auth/login', data),

  // ─── Dashboard ─────────────────────────────────────────────────────────────
  getDashboardStats: () => apiClient.get('/admin/dashboard'),
  getAnalytics: (params: any) => apiClient.get('/admin/analytics', { params }),

  // ─── Users ─────────────────────────────────────────────────────────────────
  getUsers: (params: any) => apiClient.get('/admin/users', { params }),
  getUser: (id: string) => apiClient.get(`/admin/users/${id}`),
  updateUser: (id: string, data: any) => apiClient.put(`/admin/users/${id}`, data),
  verifyUser: (id: string) => apiClient.post(`/admin/users/${id}/verify`),
  blockUser: (id: string, reason?: string) => apiClient.post(`/admin/users/${id}/block`, { reason }),
  unblockUser: (id: string) => apiClient.post(`/admin/users/${id}/unblock`),
  upgradeMembership: (id: string, membershipType: string, daysToAdd?: number) =>
    apiClient.post(`/admin/users/${id}/upgrade-membership`, { membershipType, daysToAdd }),

  // ─── Verification Requests ─────────────────────────────────────────────────
  getVerificationRequests: (params: any) => apiClient.get('/admin/verification-requests', { params }),
  getVerificationRequest: (id: string) => apiClient.get(`/admin/verification-requests/${id}`),
  approveVerification: (id: string) => apiClient.post(`/admin/verification-requests/${id}/approve`),
  rejectVerification: (id: string, reason: string) =>
    apiClient.post(`/admin/verification-requests/${id}/reject`, { reason }),

  // ─── Requirements ──────────────────────────────────────────────────────────
  getRequirements: (params: any) => apiClient.get('/admin/requirements', { params }),
  updateRequirement: (id: string, data: any) => apiClient.put(`/admin/requirements/${id}`, data),
  deleteRequirement: (id: string) => apiClient.delete(`/admin/requirements/${id}`),

  // ─── Vehicles ──────────────────────────────────────────────────────────────
  getVehicles: (params: any) => apiClient.get('/admin/vehicles', { params }),
  updateVehicle: (id: string, data: any) => apiClient.put(`/admin/vehicles/${id}`, data),
  deleteVehicle: (id: string) => apiClient.delete(`/admin/vehicles/${id}`),

  // ─── Payments ──────────────────────────────────────────────────────────────
  getPayments: (params: any) => apiClient.get('/admin/payments', { params }),
  approveManualPayment: (id: string) => apiClient.post(`/admin/payments/${id}/approve`),

  // ─── Referrals ─────────────────────────────────────────────────────────────
  getReferralLeaderboard: (params?: any) => apiClient.get('/admin/referral-leaderboard', { params }),

  // ─── Wallets ───────────────────────────────────────────────────────────────
  getWallets: (params: any) => apiClient.get('/admin/wallets', { params }),
  adjustWallet: (userId: string, data: { amount: number; type: 'credit' | 'debit'; reason: string }) =>
    apiClient.post(`/admin/wallets/${userId}/adjust`, data),

  // ─── Cities ────────────────────────────────────────────────────────────────
  getCities: (params?: any) => apiClient.get('/admin/cities', { params }),
  createCity: (data: any) => apiClient.post('/admin/cities', data),
  updateCity: (id: string, data: any) => apiClient.put(`/admin/cities/${id}`, data),
  deleteCity: (id: string) => apiClient.delete(`/admin/cities/${id}`),

  // ─── Banners ───────────────────────────────────────────────────────────────
  getBanners: (params?: any) => apiClient.get('/admin/banners', { params }),
  createBanner: (data: any) => apiClient.post('/admin/banners', data),
  updateBanner: (id: string, data: any) => apiClient.put(`/admin/banners/${id}`, data),
  deleteBanner: (id: string) => apiClient.delete(`/admin/banners/${id}`),
  uploadBannerImage: (file: File) => {
    const fd = new FormData();
    fd.append('file', file);
    return apiClient.post('/storage/upload/banner', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  // ─── Reports ───────────────────────────────────────────────────────────────
  getReports: (params?: any) => apiClient.get('/admin/reports', { params }),
  resolveReport: (id: string, data: any) => apiClient.post(`/admin/reports/${id}/resolve`, data),

  // ─── Platform Settings ─────────────────────────────────────────────────────
  getSettings: () => apiClient.get('/settings'),
  updateSettings: (data: { pricePerKm?: number; commissionPercent?: number }) =>
    apiClient.put('/settings', data),

  // ─── Notifications ─────────────────────────────────────────────────────────
  sendNotification: (data: any) => apiClient.post('/admin/notifications/send', data),
  sendAdminNotification: (data: any) => apiClient.post('/admin/notifications/send', data),

  // ─── Subscriptions ─────────────────────────────────────────────────────────
  getSubscriptionPlans: () => apiClient.get('/subscriptions/plans'),
  getSubscriptions: (params: any) => apiClient.get('/admin/subscriptions', { params }),
  createPlan: (data: any) => apiClient.post('/admin/subscription-plans', data),
  updatePlan: (id: string, data: any) => apiClient.put(`/admin/subscription-plans/${id}`, data),
  deletePlan: (id: string) => apiClient.delete(`/admin/subscription-plans/${id}`),
};

export default apiClient;
