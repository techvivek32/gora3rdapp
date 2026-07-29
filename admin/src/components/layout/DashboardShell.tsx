'use client';

import { useEffect, useState } from 'react';
import { Minimize2 } from 'lucide-react';
import Sidebar from './Sidebar';
import Header from './Header';
import { FullscreenContext, useFullscreen } from './FullscreenContext';

// Re-exported so existing pages that import it from here keep working.
export { useFullscreen };

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
    <FullscreenContext.Provider value={{ fullscreen, toggleFullscreen }}>
      <div className="flex h-screen overflow-hidden bg-gray-50 dark:bg-gray-900">
        {!fullscreen && <Sidebar />}
        <div className="flex-1 flex flex-col overflow-hidden">
          {!fullscreen && <Header />}

          {/* In fullscreen the full header is hidden; show a slim bar with just
              the exit control. It occupies layout space (not an overlay), so it
              never covers page buttons or table actions. Escape also works. */}
          {fullscreen && (
            <div className="flex-shrink-0 flex items-center justify-end h-11 px-4 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">
              <button
                onClick={toggleFullscreen}
                title="Exit Fullscreen (Esc)"
                className="flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              >
                <Minimize2 className="w-4 h-4" />
                Exit Fullscreen
              </button>
            </div>
          )}

          <main className="flex-1 overflow-y-auto p-6">{children}</main>
        </div>
      </div>
    </FullscreenContext.Provider>
  );
}
