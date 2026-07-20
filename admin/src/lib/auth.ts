import { NextAuthOptions } from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://backend.goracabs.com/api/v1';

// Read the real expiry (ms) from a JWT's `exp` claim; fall back to 15 min.
function jwtExpiryMs(jwt?: string): number {
  try {
    const payload = JSON.parse(Buffer.from(jwt!.split('.')[1], 'base64url').toString());
    if (payload?.exp) return payload.exp * 1000;
  } catch {
    /* ignore */
  }
  return Date.now() + 15 * 60 * 1000;
}

// Exchange the refresh token for a fresh access token. On failure, flag the token
// so the client can auto-logout.
async function refreshAccessToken(token: any) {
  try {
    const res = await axios.post(`${API_URL}/auth/refresh`, {
      userId: token.userId,
      refreshToken: token.refreshToken,
    });
    const data = res.data?.data ?? {};
    return {
      ...token,
      accessToken: data.accessToken,
      refreshToken: data.refreshToken ?? token.refreshToken,
      accessTokenExpires: jwtExpiryMs(data.accessToken),
      error: undefined,
    };
  } catch {
    return { ...token, error: 'RefreshAccessTokenError' };
  }
}

export const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        // 1) Try the normal admin / super-admin login first.
        try {
          const response = await axios.post(`${API_URL}/auth/login`, {
            identifier: credentials?.email,
            password: credentials?.password,
          });

          const { data } = response.data;
          const user = data?.user;

          if (user && ['admin', 'super_admin'].includes(user.role)) {
            return {
              id: user._id,
              name: user.fullName,
              email: user.email,
              role: user.role,
              franchiseCity: null,
              accessToken: data.accessToken,
              refreshToken: data.refreshToken,
            };
          }
          // A real app user (not admin) reached here — fall through to franchise.
        } catch {
          // Not a user/admin account (or wrong password there) — try franchise next.
        }

        // 2) Fall back to a franchise login (separate identity space).
        try {
          const res = await axios.post(`${API_URL}/auth/franchise/login`, {
            identifier: credentials?.email,
            password: credentials?.password,
          });
          const { data } = res.data;
          const f = data?.franchise;
          if (!f) throw new Error('Invalid credentials');

          return {
            id: f.id,
            name: f.name,
            email: f.email,
            role: 'franchise',
            franchiseCity: f.city ?? null,
            accessToken: data.accessToken,
            refreshToken: data.refreshToken,
          };
        } catch (error: any) {
          throw new Error(error.response?.data?.message || 'Invalid email or password');
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      // Initial sign in.
      if (user) {
        token.accessToken = (user as any).accessToken;
        token.refreshToken = (user as any).refreshToken;
        token.userId = (user as any).id;
        token.role = (user as any).role;
        token.franchiseCity = (user as any).franchiseCity ?? null;
        token.accessTokenExpires = jwtExpiryMs((user as any).accessToken);
        token.error = undefined;
        return token;
      }

      // Still valid (refresh a bit early — while >5 min remain, keep it).
      if (token.accessTokenExpires && Date.now() < (token.accessTokenExpires as number) - 5 * 60 * 1000) {
        return token;
      }

      // Access token (near) expired → refresh using the long-lived refresh token.
      return await refreshAccessToken(token);
    },
    async session({ session, token }) {
      session.user.accessToken = token.accessToken as string;
      session.user.refreshToken = token.refreshToken as string;
      session.user.role = token.role as string;
      (session.user as any).franchiseCity = (token as any).franchiseCity ?? null;
      (session as any).error = (token as any).error;
      return session;
    },
  },
  pages: {
    signIn: '/login',
    error: '/login',
  },
  // Admin session lasts 24h and rolls forward on activity: the session cookie is
  // persisted (so closing/reopening the tab keeps you signed in) and is re-issued at
  // most once per hour of use, pushing its 24h expiry out. Within that window the
  // short-lived access token is auto-refreshed by the jwt callback above; only after
  // 24h of no activity does the session lapse and the user return to login.
  session: { strategy: 'jwt', maxAge: 24 * 60 * 60, updateAge: 60 * 60 },
  jwt: { maxAge: 24 * 60 * 60 },
  secret: process.env.NEXTAUTH_SECRET,
};
