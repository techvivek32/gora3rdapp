/**
 * The colour an operator can give a city chip.
 *
 * A fixed set, not a colour picker. Every solid below carries white text and
 * clears 4.5:1 against it in both themes, which a free hex cannot promise —
 * the first pale yellow someone chose would make the chip unreadable and
 * nothing would stop them. Five choices is enough to group cities by region
 * or by whatever else the operator wants to say, and none of them can break
 * the page.
 *
 * `auto` is the default and keeps what the strip did before an operator ever
 * touched it: a featured city takes the next colour in the rotation, and the
 * rest are soft. So existing rows look exactly as they did.
 *
 * Mirrored in admin/src/components/ServiceCities.tsx — two apps, no shared
 * package. If a value is added here, add it there.
 */
export const CITY_COLOURS = ['auto', 'soft', 'orange', 'teal', 'gold', 'slate'] as const;
export type CityColour = (typeof CITY_COLOURS)[number];

/** Chips in the rotation `auto` draws from, in order. */
const ROTATION = ['teal', 'gold', 'orange', 'brand'] as const;

const SOLID: Record<string, string> = {
  orange: 'bg-poolsolid',
  teal: 'bg-cabsolid',
  gold: 'bg-drivesolid',
  // Not the `luxsolid` token: these chips sit on a page surface in light mode
  // and a dark one in the other, and the token is tuned per-surface — on the
  // dark theme it came out as slate on slate.
  slate: 'bg-slate-500',
  brand: 'bg-brand-600',
};

const SOFT =
  'inline-flex items-center gap-2 rounded-full bg-tint px-5 py-2.5 text-sm font-bold text-brandink ring-1 ring-tintline';
const SOLID_BASE =
  'inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-bold text-white shadow-glow';

/**
 * The classes for one chip, and whether it ended up solid — the state label
 * beside the name needs to know, because it is white on a solid and muted on
 * a soft one.
 *
 * `index` only matters for `auto`, which is why it is the rotation's input
 * and not the colour's.
 */
export function cityChip(
  colour: string | undefined,
  isFeatured: boolean | undefined,
  index: number,
): { className: string; solid: boolean } {
  const choice = (colour || 'auto').toLowerCase();

  if (choice === 'soft') return { className: SOFT, solid: false };

  const key =
    choice === 'auto'
      ? isFeatured
        ? ROTATION[index % ROTATION.length]
        : null
      : choice;

  const bg = key ? SOLID[key] : undefined;
  if (!bg) return { className: SOFT, solid: false };
  return { className: `${SOLID_BASE} ${bg}`, solid: true };
}
