'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import Sidebar from './Sidebar';
import Header from './Header';

interface FullscreenCtx {
  fullscreen: boolean;
  toggleFullscreen: () => void;
}

const Ctx = createContext<FullscreenCtx>({ fullscreen: false, toggleFullscreen: () => {} });

/** Lets any page hide the sidebar + header to use the full window. */
export const useFullscreen = () => useContext(Ctx);

/**
 * Client shell around the dashboard chrome. The layout itself is a server
 * component (it checks the session), so the show/hide state lives here.
 */
export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const [fullscreen, setFullscreen] = useState(false);

  const toggleFullscreen = () => setFullscreen((v) => !v);

  // Escape always gets you out — otherwise a page that hides its own toggle
  // button would trap the admin with no chrome and no way back.
  useEffect(() => {
    if (!fullscreen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setFullscreen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [fullscreen]);

  return (
    <Ctx.Provider value={{ fullscreen, toggleFullscreen }}>
      <div className="flex h-screen overflow-hidden bg-gray-50 dark:bg-gray-900">
        {!fullscreen && <Sidebar />}
        <div className="flex-1 flex flex-col overflow-hidden">
          {!fullscreen && <Header />}
          <main className="flex-1 overflow-y-auto p-6">{children}</main>
        </div>
      </div>
    </Ctx.Provider>
  );
}
