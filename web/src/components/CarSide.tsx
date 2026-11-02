/**
 * Side view of a sedan, drawn so that it reads as moving.
 *
 * The first version had plain dark discs for wheels, and a plain disc spinning
 * looks exactly like a plain disc standing still — there is nothing on it for
 * the eye to track. So each wheel carries a dashed tread around the tyre and
 * five alloy spokes, which is what makes the rotation visible at all.
 *
 * Shared by the opening sequence and the home hero rather than drawn twice:
 * the two would have drifted apart the first time either was touched.
 */
export function CarSide({ className = '' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 150 58" fill="none" aria-hidden>
      {/* Contact shadow. Sits under everything and is wider than the car, so
          the car reads as being ON the road rather than in front of it. */}
      <ellipse cx="75" cy="50" rx="58" ry="4" fill="#000" opacity="0.35" />

      {/* Headlight throw. Short and faint — a cone the length of the bonnet
          says "lit" without turning the car into a torch. */}
      <path d="M138 34 L150 28 L150 41 L138 37 Z" fill="#fff7ed" opacity="0.22" />

      {/* Body. A single shell: nose, bonnet, windscreen rake, roof, boot. */}
      <path
        d="M8 41
           L9 31 Q10 25 17 24
           L41 24 L53 12 Q56 9 62 9
           L88 9 Q94 9 97 12 L107 24
           L128 27 Q140 29 142 37
           L143 41 Q143 44 139 44
           L12 44 Q8 44 8 41 Z"
        fill="#f97316"
      />
      {/* A darker skirt along the sill gives the body some weight. */}
      <path d="M9 38 L143 40 L143 41 Q143 44 139 44 L12 44 Q8 44 8 41 Z" fill="#c2410c" />

      {/* Glass. Two panes with a pillar between them. */}
      <path d="M56 23 L65 13 L78 13 L78 23 Z" fill="#9ad5f5" opacity="0.85" />
      <path d="M82 13 L87 13 L96 23 L82 23 Z" fill="#9ad5f5" opacity="0.85" />
      {/* A highlight across the glass, as if the sky were in it. */}
      <path d="M58 22 L66 14 L70 14 L60 22 Z" fill="#ffffff" opacity="0.45" />

      {/* Door shut line and handle. */}
      <path d="M78 24 L78 40" stroke="#c2410c" strokeWidth="1.2" />
      <rect x="83" y="29" width="7" height="2" rx="1" fill="#c2410c" />
      {/* Wing mirror. */}
      <path d="M55 23 L50 21 L50 24 Z" fill="#c2410c" />

      {/* Lights. */}
      <rect x="137" y="30" width="6" height="4" rx="1.6" fill="#fffbeb" />
      <rect x="8" y="30" width="4" height="3.5" rx="1.2" fill="#fca5a5" />

      {/* Wheel arches, drawn over the body so the tyres sit inside them. */}
      <path d="M26 44 A14 14 0 0 1 54 44 Z" fill="#9a3412" />
      <path d="M100 44 A14 14 0 0 1 128 44 Z" fill="#9a3412" />

      <Wheel cx={40} cy={42} />
      <Wheel cx={114} cy={42} />
    </svg>
  );
}

/** One wheel. Everything inside the rotating group turns together. */
function Wheel({ cx, cy }: { cx: number; cy: number }) {
  // Five spokes. At speed these strobe, which is exactly what a real alloy
  // does on camera and is far more legible than a smooth blur.
  const spokes = [0, 72, 144, 216, 288].map((deg) => (
    <rect
      key={deg}
      x={cx - 1.1}
      y={cy - 6}
      width="2.2"
      height="5"
      rx="1.1"
      fill="#e2e8f0"
      transform={`rotate(${deg} ${cx} ${cy})`}
    />
  ));

  return (
    <g className="intro-wheel">
      {/* Tyre */}
      <circle cx={cx} cy={cy} r="11" fill="#0f141f" />
      {/* Tread: a dashed ring, and the single clearest cue that it is turning */}
      <circle
        cx={cx}
        cy={cy}
        r="9.6"
        fill="none"
        stroke="#1e293b"
        strokeWidth="2.6"
        strokeDasharray="2.6 3.2"
      />
      {/* Alloy */}
      <circle cx={cx} cy={cy} r="6.4" fill="#94a3b8" />
      {spokes}
      <circle cx={cx} cy={cy} r="2.1" fill="#475569" />
      {/* One off-centre nub, so rotation is readable even if the spokes strobe
          into looking still. */}
      <circle cx={cx + 3.6} cy={cy - 3.6} r="0.9" fill="#1e293b" />
    </g>
  );
}
