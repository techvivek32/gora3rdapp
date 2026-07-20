import 'next-auth';
import 'next-auth/jwt';

declare module 'next-auth' {
  interface Session {
    user: {
      id: string;
      name?: string | null;
      email?: string | null;
      image?: string | null;
      role: string;
      // Set only for franchise sessions — the city all data is scoped to.
      franchiseCity?: string | null;
      accessToken: string;
      refreshToken: string;
    };
  }

  interface User {
    id: string;
    role: string;
    franchiseCity?: string | null;
    accessToken: string;
    refreshToken: string;
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    role: string;
    franchiseCity?: string | null;
    accessToken: string;
    refreshToken: string;
  }
}
