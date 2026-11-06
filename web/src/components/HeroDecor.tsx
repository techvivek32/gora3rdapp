/**
 * The blue in the background, as shapes.
 *
 * A wash of blue across the band was tried first and it disappeared —
 * measured at 4% colourfulness, against the reference's 235 on its blue
 * element. Colour reads when it has an EDGE, so this is geometry: rings, a
 * dot grid, a square on its corner.
 *
 * Two things were wrong with the first attempt and both are worth keeping in
 * mind if these are moved. A 1.5px line at 20% over a near-white page is not
 * faint, it is invisible; these are 2px at 40-55%. And half the shapes were
 * placed where the content is, so the booking panel and the photo card sat
 * on top of them — they are now in the four parts of the band that are
 * genuinely empty: the left gutter, above and below the media, and the strip
 * past its right edge.
 *
 * All decoration, no meaning: `aria-hidden`, no pointer, behind the content.
 */
export function HeroDecor() {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
      {/* Left gutter — the column of page outside the text measure. */}
      <div
        className="absolute -left-8 top-[26rem] hidden h-80 w-44 lg:block"
        style={{
          backgroundImage: 'radial-gradient(rgb(var(--blue) / 0.55) 2px, transparent 2px)',
          backgroundSize: '20px 20px',
          WebkitMaskImage: 'linear-gradient(to bottom, transparent, #000 25%, #000 70%, transparent)',
          maskImage: 'linear-gradient(to bottom, transparent, #000 25%, #000 70%, transparent)',
        }}
      />

      {/* Top right, above the media: a big ring breaking the top edge, with
          a soft disc inside it so the set is not all wireframe. */}
      <div className="absolute -top-40 right-[4%] h-[26rem] w-[26rem] rounded-full border-2 border-blue/40" />
      <div className="absolute -top-16 right-[18%] hidden h-36 w-36 rounded-full bg-blue/[0.10] lg:block" />

      {/* Past the media's right edge. */}
      <div className="absolute right-[-3.5rem] top-[22rem] hidden h-32 w-32 rotate-[18deg] rounded-[2rem] border-2 border-blue/40 lg:block" />

      {/* Below the media, where the band runs out before the counters. */}
      <div className="absolute bottom-6 right-[14%] hidden h-44 w-44 rounded-full border-2 border-blue/35 lg:block" />
      <div className="absolute bottom-[6.5rem] right-[30%] hidden h-3.5 w-3.5 rounded-full bg-blue lg:block" />

      {/* Bottom left, a quarter ring rising out of the corner — the only
          shape that reads on a phone, where the rest are hidden. */}
      <div className="absolute -bottom-44 -left-28 h-80 w-80 rounded-full border-2 border-blue/30" />
    </div>
  );
}
