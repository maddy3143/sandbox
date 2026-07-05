import {
  AbsoluteFill,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import type { CSSProperties } from "react";

const GOLD = "#C9A227";
const NAVY = "#0A1628";

const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };
const ez = Easing.bezier(0.16, 1, 0.3, 1);

// Golden particle dot
const Particle: React.FC<{ x: number; y: number; delay: number; size: number }> = ({
  x, y, delay, size,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const f = Math.max(0, frame - delay);
  const opacity = interpolate(f, [0, 20, durationInFrames - 30], [0, 0.8, 0], clamp);
  const translateY = interpolate(f, [0, durationInFrames], [0, -30], clamp);
  return (
    <div
      style={{
        position: "absolute",
        left: `${x}%`,
        top: `${y}%`,
        width: size,
        height: size,
        borderRadius: "50%",
        background: GOLD,
        opacity,
        translate: `0 ${translateY}px`,
        boxShadow: `0 0 ${size * 3}px ${GOLD}`,
      }}
    />
  );
};

const PARTICLES = Array.from({ length: 60 }, (_, i) => ({
  x: Math.random() * 100,
  y: Math.random() * 100,
  delay: Math.floor(Math.random() * 40),
  size: 2 + Math.random() * 4,
}));

// Andhra Pradesh outline SVG path (simplified)
const AP_PATH =
  "M 960 200 L 1050 220 L 1130 280 L 1160 360 L 1140 440 L 1080 500 L 1020 560 L 960 600 L 880 580 L 820 520 L 780 440 L 800 360 L 850 280 Z";

const APMap: React.FC = () => {
  const frame = useCurrentFrame();
  const length = 500;
  const dashoffset = interpolate(frame, [0, 60], [length, 0], { ...clamp, easing: ez });
  const pinOpacity = interpolate(frame, [50, 80], [0, 1], clamp);
  const pinScale = interpolate(frame, [50, 75], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.56, 0.64, 1) });

  return (
    <svg viewBox="780 190 400 430" style={{ width: 360, height: 390 }}>
      <path
        d={AP_PATH}
        fill="none"
        stroke={GOLD}
        strokeWidth={2}
        strokeDasharray={length}
        strokeDashoffset={dashoffset}
        opacity={0.9}
      />
      <circle cx="960" cy="400" r={6} fill={GOLD} opacity={pinOpacity} style={{ scale: String(pinScale), transformOrigin: "960px 400px" }} />
      <circle cx="960" cy="400" r={14} fill="none" stroke={GOLD} strokeWidth={1.5} opacity={pinOpacity * 0.5} />
      <text x="960" y="430" textAnchor="middle" fill={GOLD} fontSize={13} fontWeight="bold" opacity={pinOpacity} fontFamily="sans-serif">
        ధర్మవరం
      </text>
    </svg>
  );
};

export const Intro: React.FC = () => {
  const frame = useCurrentFrame();

  const bgOpacity = interpolate(frame, [0, 20], [1, 0.0], clamp);

  // Cover page (page-01) fade in as minister background
  const ministerOpacity = interpolate(frame, [150, 230], [0, 1], { ...clamp, easing: ez });
  const ministerScale = interpolate(frame, [150, 260], [1.1, 1.0], clamp);

  // Emblem
  const emblemOpacity = interpolate(frame, [40, 120], [0, 1], { ...clamp, easing: ez });
  const emblemScale = interpolate(frame, [40, 120], [0.7, 1.0], { ...clamp, easing: ez });

  // Map
  const mapOpacity = interpolate(frame, [100, 160], [0, 1], clamp);

  // Title
  const titleOpacity = interpolate(frame, [260, 340], [0, 1], { ...clamp, easing: ez });
  const titleY = interpolate(frame, [260, 340], [30, 0], { ...clamp, easing: ez });

  // Sub-title
  const subOpacity = interpolate(frame, [310, 380], [0, 1], { ...clamp, easing: ez });

  // Logos bar
  const logosOpacity = interpolate(frame, [380, 450], [0, 1], { ...clamp, easing: ez });

  // Light ray
  const rayOpacity = interpolate(frame, [150, 250, 450], [0, 0.15, 0], clamp);

  const overlayStyle: CSSProperties = {
    position: "absolute",
    inset: 0,
    background: NAVY,
    opacity: bgOpacity,
    zIndex: 10,
  };

  return (
    <AbsoluteFill style={{ background: NAVY, overflow: "hidden" }}>
      {/* Minister cover image */}
      <AbsoluteFill style={{ opacity: ministerOpacity }}>
        <Img
          src={staticFile("pages/page-01.png")}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "center top",
            scale: String(ministerScale),
          }}
        />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, rgba(10,22,40,0.85) 0%, rgba(10,22,40,0.4) 50%, rgba(10,22,40,0.85) 100%)" }} />
      </AbsoluteFill>

      {/* Particles */}
      {PARTICLES.map((p, i) => (
        <Particle key={i} {...p} />
      ))}

      {/* Radial light ray behind minister */}
      <div style={{
        position: "absolute",
        inset: 0,
        background: `radial-gradient(ellipse 500px 700px at 70% 50%, rgba(201,162,39,${rayOpacity}) 0%, transparent 70%)`,
      }} />

      {/* AP State emblem (gold circle placeholder) */}
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "flex-start", paddingTop: 60, opacity: emblemOpacity }}>
        <div style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          scale: String(emblemScale),
          marginLeft: 120,
        }}>
          <div style={{
            width: 90, height: 90, borderRadius: "50%",
            border: `3px solid ${GOLD}`,
            background: "rgba(201,162,39,0.12)",
            display: "flex", alignItems: "center", justifyContent: "center",
            boxShadow: `0 0 30px rgba(201,162,39,0.4)`,
          }}>
            <span style={{ fontSize: 36, color: GOLD }}>🏛</span>
          </div>
          <div style={{ color: GOLD, fontSize: 13, marginTop: 8, letterSpacing: 2, fontFamily: "'Noto Sans Telugu', sans-serif" }}>
            ఆంధ్రప్రదేశ్ ప్రభుత్వం
          </div>
        </div>
      </AbsoluteFill>

      {/* AP Map */}
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "flex-start", paddingLeft: 80, opacity: mapOpacity }}>
        <div style={{ marginTop: 160 }}>
          <APMap />
        </div>
      </AbsoluteFill>

      {/* Main title block — right side */}
      <AbsoluteFill style={{ alignItems: "flex-end", justifyContent: "center", paddingRight: 100 }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 16 }}>
          {/* Title */}
          <div style={{
            opacity: titleOpacity,
            translate: `0 ${titleY}px`,
            textAlign: "right",
          }}>
            <div style={{ color: GOLD, fontSize: 22, letterSpacing: 4, fontFamily: "'Noto Sans Telugu', sans-serif", marginBottom: 6 }}>
              ధర్మవరం నియోజకవర్గం
            </div>
            <div style={{
              color: "#ffffff",
              fontSize: 64,
              fontWeight: 800,
              lineHeight: 1.1,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              textShadow: "0 4px 24px rgba(0,0,0,0.6)",
            }}>
              రెండు సంవత్సరాలు
            </div>
            <div style={{ color: GOLD, fontSize: 52, fontWeight: 700, fontFamily: "'Noto Sans Telugu', sans-serif" }}>
              మంచి పాలన
            </div>
          </div>

          {/* Sub-title — minister name */}
          <div style={{ opacity: subOpacity, textAlign: "right" }}>
            <div style={{ color: "#e0e0e0", fontSize: 18, fontFamily: "'Noto Sans Telugu', sans-serif", letterSpacing: 1 }}>
              శ్రీ వై. సత్య కుమార్ యాదవ్ గారు
            </div>
            <div style={{ color: GOLD, fontSize: 14, fontFamily: "'Noto Sans Telugu', sans-serif", letterSpacing: 2, marginTop: 4 }}>
              ఆరోగ్య మంత్రి • ఆంధ్రప్రదేశ్ ప్రభుత్వం
            </div>
          </div>

          {/* Party logos bar */}
          <div style={{
            opacity: logosOpacity,
            display: "flex",
            gap: 24,
            alignItems: "center",
            marginTop: 8,
            background: "rgba(201,162,39,0.1)",
            border: `1px solid rgba(201,162,39,0.3)`,
            borderRadius: 8,
            padding: "10px 20px",
          }}>
            {["TDP", "BJP", "జనసేన"].map((p) => (
              <div key={p} style={{ color: GOLD, fontSize: 16, fontWeight: 700, fontFamily: "'Noto Sans Telugu', sans-serif", letterSpacing: 1 }}>
                {p}
              </div>
            ))}
          </div>
        </div>
      </AbsoluteFill>

      {/* Initial black overlay */}
      <div style={overlayStyle} />
    </AbsoluteFill>
  );
};
