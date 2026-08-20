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
    // Note: we intentionally do NOT force a sign-out on a 401 here. On a page reload
    // a query can briefly race ahead of the session refresh and fire with a stale
    // access token, producing a transient 401 — hard sign-out here used to log the
    // admin out on every refresh. React Query retries the request once the refreshed
    // token lands (SessionSync). Genuine session expiry (refresh token dead) is handled
    // in providers.tsx, which signs out when the session reports RefreshAccessTokenError.
    const message = error.response?.data?.message || error.message || 'Something went wrong';
    return Promise.reject(new Error(message));
  },
);

export const adminApi = {
  // ─── Auth ──────────────────────────────────────────────────────────────────
  login: (data: { identifier: string; password: string }) =>
    apiClient.post('/auth/login', data),
  // Admin/super-admin forgot password via phone OTP (public endpoints).
  adminForgotSendOtp: (mobile: string) =>
    apiClient.post('/auth/admin/forgot-password/send-otp', { mobile }),
  adminForgotReset: (data: { mobile: string; otp: string; newPassword: string }) =>
    apiClient.post('/auth/admin/forgot-password/reset', data),

  // ─── Dashboard ─────────────────────────────────────────────────────────────
  getDashboardStats: (params?: any) => apiClient.get('/admin/dashboard', { params }),
  getAnalytics: (params: any) => apiClient.get('/admin/analytics', { params }),

  // ─── Users ─────────────────────────────────────────────────────────────────
  getUsers: (params: any) => apiClient.get('/admin/users', { params }),
  getUser: (id: string) => apiClient.get(`/admin/users/${id}`),
  updateUser: (id: string, data: any) => apiClient.put(`/admin/users/${id}`, data),
  verifyUser: (id: string) => apiClient.post(`/admin/users/${id}/verify`),
  blockUser: (id: string, reason?: string) => apiClient.post(`/admin/users/${id}/block`, { reason }),
  unblockUser: (id: string) => apiClient.post(`/admin/users/${id}/unblock`),
  upgradeMembership: (id: string, membershipType: string, daysToAdd?: number, planId?: string) =>
    apiClient.post(`/admin/users/${id}/upgrade-membership`, { membershipType, daysToAdd, planId }),
  getUserRequirements: (id: string) => apiClient.get(`/admin/users/${id}/requirements`),
  getUserVehicles: (id: string) => apiClient.get(`/admin/users/${id}/vehicles`),
  // Post on behalf of a user (admin adds a requirement / available cab for them).
  createRequirementFor: (id: string, data: any) => apiClient.post(`/admin/users/${id}/requirements`, data),
  createVehicleFor: (id: string, data: any) => apiClient.post(`/admin/users/${id}/vehicles`, data),
  getUserPayments: (id: string) => apiClient.get(`/admin/users/${id}/payments`),
  getUserWithdrawals: (id: string) => apiClient.get(`/admin/users/${id}/withdrawals`),
  getUserReviews: (id: string) => apiClient.get(`/admin/users/${id}/reviews`),
  updateReview: (id: string, data: { stars?: number; review?: string }) => apiClient.put(`/admin/reviews/${id}`, data),
  deleteReview: (id: string) => apiClient.delete(`/admin/reviews/${id}`),
  getUserSubscriptions: (id: string) => apiClient.get(`/admin/users/${id}/subscriptions`),
  cancelSubscription: (id: string) => apiClient.post(`/admin/subscriptions/${id}/cancel`),
  updateSubscriptionEndDate: (id: string, endDate: string) => apiClient.put(`/admin/subscriptions/${id}/end-date`, { endDate }),

  // ─── Verification Requests ─────────────────────────────────────────────────
  getVerificationRequests: (params: any) => apiClient.get('/admin/verification-requests', { params }),
  getVerificationRequest: (id: string) => apiClient.get(`/admin/verification-requests/${id}`),
  approveVerification: (id: string) => apiClient.post(`/admin/verification-requests/${id}/approve`),
  rejectVerification: (id: string, reason: string) =>
    apiClient.post(`/admin/verification-requests/${id}/reject`, { reason }),
  // Approve/reject one KYC document (aadhar | pan | drivingLicense | vehicleRc).
  reviewDocument: (id: string, doc: string, status: 'approved' | 'rejected', reason?: string) =>
    apiClient.post(`/admin/verification-requests/${id}/documents/${doc}`, { status, reason }),

  // ─── Requirements ──────────────────────────────────────────────────────────
  getRequirements: (params: any) => apiClient.get('/admin/requirements', { params }),
  updateRequirement: (id: string, data: any) => apiClient.put(`/admin/requirements/${id}`, data),
  deleteRequirement: (id: string) => apiClient.delete(`/admin/requirements/${id}`),

  // ─── Places (Google autocomplete, proxied) ───────────────────────────────────
  placesAutocomplete: (input: string) => apiClient.get('/places/autocomplete', { params: { input, types: 'geocode' } }),
  placeDetails: (placeId: string) => apiClient.get('/places/details', { params: { placeId } }),

  // ─── Vehicles ──────────────────────────────────────────────────────────────
  getVehicles: (params: any) => apiClient.get('/admin/vehicles', { params }),
  updateVehicle: (id: string, data: any) => apiClient.put(`/admin/vehicles/${id}`, data),
  deleteVehicle: (id: string) => apiClient.delete(`/admin/vehicles/${id}`),

  // ─── Payments ──────────────────────────────────────────────────────────────
  getPayments: (params: any) => apiClient.get('/admin/payments', { params }),
  approveManualPayment: (id: string) => apiClient.post(`/admin/payments/${id}/approve`),

  // ─── Support Chats ─────────────────────────────────────────────────────────
  getSupportChats: () => apiClient.get('/admin/support/conversations'),
  getSupportConversation: (userId: string) => apiClient.get(`/admin/support/conversations/${userId}`),
  replySupport: (userId: string, text: string) => apiClient.post(`/admin/support/conversations/${userId}/reply`, { text }),

  // ─── Referrals ─────────────────────────────────────────────────────────────
  getReferralLeaderboard: (params?: any) => apiClient.get('/admin/referral-leaderboard', { params }),
  updateUserReferralCount: (userId: string, delta: number) =>
    apiClient.post(`/admin/users/${userId}/referral-count`, { delta }),

  // ─── Wallets ───────────────────────────────────────────────────────────────
  getWallets: (params: any) => apiClient.get('/admin/wallets', { params }),
  getUserWallet: (userId: string) => apiClient.get(`/admin/wallets/${userId}`),
  adjustWallet: (userId: string, data: { amount: number; type: 'credit' | 'debit'; reason: string }) =>
    apiClient.post(`/admin/wallets/${userId}/adjust`, data),
  // Sends from `userId`'s wallet to the user with that mobile number.
  transferWallet: (userId: string, data: { mobile: string; amount: number; note?: string }) =>
    apiClient.post(`/admin/wallets/${userId}/transfer`, data),
  lookupUserByMobile: (mobile: string) => apiClient.get('/users/lookup', { params: { mobile } }),

  // ─── Withdrawals ─────────────────────────────────────────────────────────────
  getWithdrawals: (params?: { status?: string; search?: string; dateFrom?: string; dateTo?: string }) => apiClient.get('/admin/wallets/withdrawals', { params }),
  approveWithdrawal: (id: string) => apiClient.post(`/admin/wallets/withdrawals/${id}/approve`),
  rejectWithdrawal: (id: string, reason: string) => apiClient.post(`/admin/wallets/withdrawals/${id}/reject`, { reason }),

  // ─── Cities ────────────────────────────────────────────────────────────────
  getCities: (params?: any) => apiClient.get('/admin/cities', { params }),
  getCityInsights: (params?: any) => apiClient.get('/admin/city-insights', { params }),
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

  // ─── Ringtones (admin only) ──────────────────────────────────────────────────
  getRingtones: () => apiClient.get('/admin/ringtones'),
  createRingtone: (data: { title: string; audioUrl: string; sortOrder?: number }) =>
    apiClient.post('/admin/ringtones', data),
  updateRingtone: (id: string, data: { title?: string; sortOrder?: number; isActive?: boolean }) =>
    apiClient.put(`/admin/ringtones/${id}`, data),
  deleteRingtone: (id: string) => apiClient.delete(`/admin/ringtones/${id}`),
  uploadRingtone: (file: File) => {
    const fd = new FormData();
    fd.append('file', file);
    return apiClient.post('/storage/upload/ringtone', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  // ─── Popup Ads (admin only) ─────────────────────────────────────────────────
  getPopupAds: () => apiClient.get('/admin/popup-ads'),
  createPopupAd: (data: { imageUrl: string; linkUrl?: string }) =>
    apiClient.post('/admin/popup-ads', data),
  updatePopupAd: (id: string, data: { linkUrl?: string; isActive?: boolean }) =>
    apiClient.put(`/admin/popup-ads/${id}`, data),
  deletePopupAd: (id: string) => apiClient.delete(`/admin/popup-ads/${id}`),
  uploadAdImage: (file: File) => {
    const fd = new FormData();
    fd.append('file', file);
    return apiClient.post('/storage/upload/ad', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  // Upload KYC documents for a user who can't do it themselves; sends for review.
  submitDocumentsFor: (id: string, documents: Record<string, any>) =>
    apiClient.post(`/admin/users/${id}/documents`, documents),
  uploadDocumentImage: (file: File) => {
    const fd = new FormData();
    fd.append('file', file);
    fd.append('folder', 'documents');
    return apiClient.post('/storage/upload', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  uploadProfileImage: (file: File) => {
    const fd = new FormData();
    fd.append('file', file);
    return apiClient.post('/storage/upload/profile', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  uploadNotificationImage: (file: File) => {
    const fd = new FormData();
    fd.append('file', file);
    return apiClient.post('/storage/upload/notification', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  // ─── Account Deletion Requests ─────────────────────────────────────────────
  getDeletionRequests: (params?: any) => apiClient.get('/admin/deletion-requests', { params }),
  approveDeletionRequest: (id: string) => apiClient.post(`/admin/deletion-requests/${id}/approve`),
  rejectDeletionRequest: (id: string, reason?: string) =>
    apiClient.post(`/admin/deletion-requests/${id}/reject`, { reason }),

  // ─── Reports ───────────────────────────────────────────────────────────────
  getReports: (params?: any) => apiClient.get('/admin/reports', { params }),
  resolveReport: (id: string, data: any) => apiClient.post(`/admin/reports/${id}/resolve`, data),

  // ─── Platform Settings ─────────────────────────────────────────────────────
  getSettings: () => apiClient.get('/settings'),
  getAdminSettings: () => apiClient.get('/settings/admin'),
  updateSettings: (data: {
    pricePerKm?: number;
    commissionPercent?: number;
    vehiclePrices?: Record<string, number>;
    razorpayKeyId?: string;
    razorpayKeySecret?: string;
    razorpayWebhookSecret?: string;
    supportPhone?: string;
    supportPhone2?: string;
    supportWhatsapp?: string;
    supportEmail?: string;
    minDeposit?: number;
    minWithdrawal?: number;
    minTransfer?: number;
    whatsappAutoBookMinutes?: number;
    appSuggestedFareEnabled?: boolean;
    viewsEnabled?: boolean;
  }) => apiClient.put('/settings', data),

  // ─── Notifications ─────────────────────────────────────────────────────────
  sendNotification: (data: any) => apiClient.post('/admin/notifications/send', data),
  sendAdminNotification: (data: any) => apiClient.post('/admin/notifications/send', data),
  getSentNotifications: (params?: any) => apiClient.get('/admin/notifications', { params }),

  // ─── Franchises ──────────────────────────────────────────────────────────────
  getFranchises: (params?: any) => apiClient.get('/admin/franchises', { params }),
  getFranchise: (id: string) => apiClient.get(`/admin/franchises/${id}`),
  createFranchise: (data: any) => apiClient.post('/admin/franchises', data),
  updateFranchise: (id: string, data: any) => apiClient.put(`/admin/franchises/${id}`, data),
  deleteFranchise: (id: string) => apiClient.delete(`/admin/franchises/${id}`),
  // All franchises ranked by their city activity/revenue (admin leaderboard page).
  getFranchiseLeaderboard: (params?: any) => apiClient.get('/admin/franchise-leaderboard', { params }),
  // ─── Login As (impersonation) ────────────────────────────────────────────
  loginAsFranchise: (id: string) => apiClient.post(`/admin/franchises/${id}/login-as`),
  exitLoginAs: () => apiClient.post('/admin/login-as/exit'),
  // Commission earnings + settlements for a franchise (admin detail page).
  getFranchiseEarnings: (id: string) => apiClient.get(`/admin/franchise-earnings/${id}`),
  settleFranchise: (id: string, data: { amount: number; note?: string }) =>
    apiClient.post(`/admin/franchise-earnings/${id}/settle`, data),
  // The logged-in franchise's own earnings (franchise panel Profile page).
  getMyFranchiseEarnings: () => apiClient.get('/admin/my-earnings'),
  // The logged-in franchise's own profile (franchise panel → Profile page).
  getFranchiseMe: () => apiClient.get('/auth/franchise/me'),
  // The logged-in admin's own profile (admin panel → Profile page).
  getAdminProfile: () => apiClient.get('/admin/profile'),
  changeAdminPassword: (data: { oldPassword: string; newPassword: string }) =>
    apiClient.post('/admin/profile/change-password', data),
  updateAdminProfile: (data: { fullName?: string; email?: string; mobile?: string }) =>
    apiClient.put('/admin/profile', data),
  activateGoldenPlan: () => apiClient.post('/admin/profile/activate-golden'),
  // Google Places city suggestions (same source the app's register page uses).
  getCitySuggestions: (input: string) => apiClient.get('/places/cities', { params: { input } }),

  // ─── Training Videos ─────────────────────────────────────────────────────────
  getTrainingVideos: () => apiClient.get('/admin/training-videos'),
  createTrainingVideo: (data: { title: string; url: string; isActive?: boolean; sortOrder?: number }) =>
    apiClient.post('/admin/training-videos', data),
  updateTrainingVideo: (id: string, data: any) => apiClient.put(`/admin/training-videos/${id}`, data),
  deleteTrainingVideo: (id: string) => apiClient.delete(`/admin/training-videos/${id}`),
  getAdminActivity: (limit = 20) => apiClient.get('/admin/activity', { params: { limit } }),

  // ─── Subscriptions ─────────────────────────────────────────────────────────
  getSubscriptionPlans: () => apiClient.get('/subscriptions/plans'),
  getPlans: () => apiClient.get('/admin/subscription-plans'),
  getSubscriptions: (params: any) => apiClient.get('/admin/subscriptions', { params }),
  createPlan: (data: any) => apiClient.post('/admin/subscription-plans', data),
  updatePlan: (id: string, data: any) => apiClient.put(`/admin/subscription-plans/${id}`, data),
  deletePlan: (id: string) => apiClient.delete(`/admin/subscription-plans/${id}`),
};

export default apiClient;
