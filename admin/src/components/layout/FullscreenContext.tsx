'use client';

import { createContext, useContext } from 'react';

interface FullscreenCtx {
  fullscreen: boolean;
  toggleFullscreen: () => void;
}

/**
 * Shared "hide the chrome" state. Kept in its own module so both the shell
 * (provider) and the Header (consumer) can import it without a circular
 * dependency.
 */
export const FullscreenContext = createContext<FullscreenCtx>({
  fullscreen: false,
  toggleFullscreen: () => {},
});

/** Lets any page or the header hide/show the sidebar + header. */
export const useFullscreen = () => useContext(FullscreenContext);
