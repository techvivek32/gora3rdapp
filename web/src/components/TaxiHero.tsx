/**
 * The hero picture, drawn rather than photographed.
 *
 * What stood here was a cut-out of whichever cab class happened to be first
 * in the fleet — a white hatchback on a white stage, with its own name under
 * it. It is a catalogue thumbnail, and the Fleet section twenty pixels below
 * already shows the same photograph at the same size. As the first thing on
 * the site it said nothing about Gora.
 *
 * This is a Gora taxi: the brand orange, the checker band every taxi in the
 * world wears, a roof sign, and the name on the door. Drawn as vector, so it
 * is sharp on any screen, weighs a few kilobytes, and carries its own warm
 * background — which is what lets it read as a picture on the white card in
 * the light theme and the dark one in the other.
 *
 * It is the FALLBACK. An operator who uploads a hero image in the admin panel
 * replaces it, and should: a photograph of their own cars beats any drawing.
 */

/** Alternating squares along the sill — the one cue that reads as "taxi". */
function Checker({ x, y, w, h, n }: { x: number; y: number; w: number; h: number; n: number }) {
  const cell = w / n;
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} fill="#fff" />
      {Array.from({ length: n }, (_, i) =>
        i % 2 === 1 ? (
          <rect key={i} x={x + i * cell} y={y} width={cell} height={h} fill="#12213d" />
        ) : null,
      )}
    </g>
  );
}

/** One wheel, with enough spoke to read as an alloy rather than a disc. */
function Wheel({ cx, cy }: { cx: number; cy: number }) {
  return (
    <g>
      <circle cx={cx} cy={cy} r="34" fill="#141a26" />
      <circle cx={cx} cy={cy} r="29" fill="none" stroke="#232c3d" strokeWidth="7" strokeDasharray="7 9" />
      <circle cx={cx} cy={cy} r="18" fill="#cbd5e1" />
      {[0, 60, 120, 180, 240, 300].map((deg) => (
        <rect
          key={deg}
          x={cx - 2.6}
          y={cy - 16}
          width="5.2"
          height="13"
          rx="2.6"
          fill="#94a3b8"
          transform={`rotate(${deg} ${cx} ${cy})`}
        />
      ))}
      <circle cx={cx} cy={cy} r="6" fill="#64748b" />
    </g>
  );
}

export function TaxiHero({ className = '' }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 560 400"
      // Fills the panel and crops, the way `object-cover` does for a photo.
      // With the default `meet` a 1.4-wide drawing in a squarer panel left a
      // band of bare card above and below it.
      preserveAspectRatio="xMidYMid slice"
      className={`font-sans ${className}`}
      role="img"
      aria-label="A Gora Taxi cab"
    >
      <defs>
        <linearGradient id="gt-sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#ffedd5" />
          <stop offset="55%" stopColor="#fed7aa" />
          <stop offset="100%" stopColor="#fdba74" />
        </linearGradient>
        <linearGradient id="gt-body" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#fb923c" />
          <stop offset="55%" stopColor="#f97316" />
          <stop offset="100%" stopColor="#ea580c" />
        </linearGradient>
        <linearGradient id="gt-glass" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#e0f2fe" />
          <stop offset="100%" stopColor="#7dd3fc" />
        </linearGradient>
        {/* The sky is a rounded rect; the sun and the skyline have to stop at
            its edge rather than square off the corners. */}
        <clipPath id="gt-frame">
          <rect x="0" y="0" width="560" height="400" rx="34" />
        </clipPath>
      </defs>

      <g clipPath="url(#gt-frame)">
        <rect x="0" y="0" width="560" height="400" fill="url(#gt-sky)" />
        <circle cx="452" cy="104" r="62" fill="#fff7ed" opacity="0.75" />

        {/* A skyline, kept to flat blocks. Any more detail and the eye goes to
            the buildings instead of the car. */}
        <g fill="#fdba74" opacity="0.55">
          <rect x="24" y="196" width="58" height="108" rx="6" />
          <rect x="92" y="156" width="44" height="148" rx="6" />
          <rect x="146" y="214" width="66" height="90" rx="6" />
          <rect x="356" y="178" width="50" height="126" rx="6" />
          <rect x="416" y="208" width="72" height="96" rx="6" />
          <rect x="498" y="168" width="40" height="136" rx="6" />
        </g>
        <g fill="#fff7ed" opacity="0.5">
          {[
            [104, 172], [104, 196], [120, 172], [120, 196],
            [368, 194], [368, 218], [384, 194], [384, 218],
            [510, 184], [510, 208], [524, 184], [524, 208],
          ].map(([x, y]) => (
            <rect key={`${x}-${y}`} x={x} y={y} width="10" height="14" rx="2" />
          ))}
        </g>

        {/* Road */}
        <rect x="0" y="304" width="560" height="96" fill="#1f2937" />
        <rect x="0" y="304" width="560" height="5" fill="#374151" />
        <g fill="#fbbf24">
          {[20, 120, 220, 320, 420, 520].map((x) => (
            <rect key={x} x={x} y="356" width="52" height="7" rx="3.5" />
          ))}
        </g>
      </g>

      {/* Everything from here down is the car, held slightly in from the
          edges: `slice` crops the sides at a squarer panel, and the one thing
          that must never be clipped is the car. */}
      <g transform="translate(281 250) scale(0.95) translate(-281 -250)">
      {/* Contact shadow. Wider than the car, so it sits ON the road. */}
      <ellipse cx="282" cy="318" rx="214" ry="15" fill="#000" opacity="0.28" />

      {/* Roof sign */}
      <g>
        <rect x="246" y="150" width="78" height="30" rx="8" fill="#12213d" />
        <rect x="246" y="150" width="78" height="9" rx="4.5" fill="#1e3a5f" />
        <text
          x="285"
          y="172"
          textAnchor="middle"
          fontSize="16"
          fontWeight="800"
          letterSpacing="2"
          fill="#fbbf24"
        >
          TAXI
        </text>
      </g>

      {/* Body: boot, cabin, bonnet, nose. */}
      <path
        d="M84 276
           L86 246 Q88 230 108 228
           L176 228 L210 190 Q218 180 236 180
           L322 180 Q340 180 348 190 L378 228
           L436 234 Q470 240 476 266
           L478 276 Q478 288 466 288
           L96 288 Q84 288 84 276 Z"
        fill="url(#gt-body)"
      />

      {/* Glass. Two panes and a pillar between them. */}
      <path d="M216 226 L244 192 Q247 188 254 188 L286 188 L286 226 Z" fill="url(#gt-glass)" />
      <path d="M296 188 L318 188 Q326 188 331 194 L355 226 L296 226 Z" fill="url(#gt-glass)" />
      <path d="M224 222 L250 194 L260 194 L234 222 Z" fill="#fff" opacity="0.5" />

      {/* Door shut line, handle and mirror. */}
      <path d="M286 186 L286 274" stroke="#c2410c" strokeWidth="3" />
      <rect x="300" y="238" width="24" height="7" rx="3.5" fill="#c2410c" />
      {/* At the foot of the A-pillar, where a mirror goes. It was at the
          rear, sticking out of the boot-side door like a little flag. */}
      <path d="M350 214 L372 209 L372 224 Z" fill="#c2410c" />

      {/* The name, on the door where a taxi carries it. */}
      <text x="196" y="258" fontSize="23" fontWeight="900" letterSpacing="0.5" fill="#fff">
        GORA
      </text>

      {/* The checker band, and the darker sill under it. */}
      <Checker x={96} y={262} w={200} h={14} n={14} />
      <path d="M86 276 L478 276 L478 277 Q478 288 466 288 L96 288 Q84 288 84 276 Z" fill="#9a3412" />

      {/* Lights */}
      <rect x="458" y="244" width="20" height="13" rx="5" fill="#fffbeb" />
      <rect x="84" y="244" width="14" height="12" rx="4" fill="#fca5a5" />

      {/* Arches over the body, so the tyres sit inside them. */}
      <path d="M126 290 A34 34 0 0 1 194 290 Z" fill="#9a3412" />
      <path d="M366 290 A34 34 0 0 1 434 290 Z" fill="#9a3412" />

      <Wheel cx={160} cy={290} />
      <Wheel cx={400} cy={290} />
      </g>
    </svg>
  );
}
