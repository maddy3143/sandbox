import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig, Easing } from "remotion";

const GOLD = "#C9A227";
const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };
const ez = Easing.bezier(0.16, 1, 0.3, 1);

const CREDITS = [
  { text: "రెండు సంవత్సరాల మంచి పాలన", size: 42, color: GOLD, weight: 800 },
  { text: "ధర్మవరం నియోజకవర్గం", size: 28, color: "#ffffff", weight: 400 },
  { text: "శ్రీ వై. సత్య కుమార్ యాదవ్ గారు", size: 32, color: "#ffffff", weight: 700 },
  { text: "ఆరోగ్య మంత్రి • ఆంధ్రప్రదేశ్ ప్రభుత్వం", size: 20, color: "#e0e0e0", weight: 400 },
  { text: "NDA ప్రభుత్వం • TDP • BJP • జనసేన", size: 20, color: GOLD, weight: 600 },
  { text: "2024 – 2026", size: 18, color: "#aaaaaa", weight: 400 },
];

export const Ending: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const src = staticFile("pages/page-30.png");

  const bgOpacity = interpolate(frame, [0, fps * 1.5], [0, 1], { ...clamp, easing: ez });
  const bgScale = interpolate(frame, [0, durationInFrames], [1.0, 1.1], clamp);

  const fadeOut = interpolate(frame, [durationInFrames - fps * 1.5, durationInFrames], [1, 0], clamp);

  return (
    <AbsoluteFill style={{ background: "#000", overflow: "hidden", opacity: fadeOut }}>
      {/* Blurred background */}
      <div style={{
        position: "absolute",
        inset: 0,
        backgroundImage: `url(${src})`,
        backgroundSize: "cover",
        backgroundPosition: "center top",
        filter: "blur(24px) brightness(0.25)",
        transform: `scale(${bgScale})`,
      }} />

      {/* Page image left-side */}
      <div style={{ position: "absolute", left: 60, top: 0, bottom: 0, display: "flex", alignItems: "center", opacity: bgOpacity }}>
        <div style={{ width: Math.round(1080 * 0.42), height: 1080 * 0.72, overflow: "hidden", borderRadius: 12, boxShadow: "0 20px 80px rgba(0,0,0,0.8)" }}>
          <Img src={src} style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: "center top" }} />
        </div>
      </div>

      {/* Golden vertical divider */}
      <div style={{
        position: "absolute",
        left: 60 + Math.round(1080 * 0.42) + 40,
        top: "15%",
        bottom: "15%",
        width: 2,
        background: `linear-gradient(to bottom, transparent, ${GOLD}, transparent)`,
        opacity: bgOpacity,
      }} />

      {/* Credits */}
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "flex-end", paddingRight: 80 }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 16, alignItems: "flex-end", maxWidth: 720 }}>
          {CREDITS.map((c, i) => {
            const delay = fps * 0.5 + i * fps * 0.25;
            const op = interpolate(frame, [delay, delay + fps * 0.8], [0, 1], { ...clamp, easing: ez });
            const ty = interpolate(frame, [delay, delay + fps * 0.8], [20, 0], { ...clamp, easing: ez });
            return (
              <div
                key={i}
                style={{
                  color: c.color,
                  fontSize: c.size,
                  fontWeight: c.weight,
                  fontFamily: "'Noto Sans Telugu', sans-serif",
                  textAlign: "right",
                  opacity: op,
                  translate: `0 ${ty}px`,
                  textShadow: "0 2px 12px rgba(0,0,0,0.8)",
                  lineHeight: 1.2,
                }}
              >
                {c.text}
              </div>
            );
          })}
        </div>
      </AbsoluteFill>

      {/* Bottom emblem */}
      <div style={{
        position: "absolute",
        bottom: 40,
        left: 0,
        right: 0,
        display: "flex",
        justifyContent: "center",
        opacity: interpolate(frame, [fps * 3, fps * 4], [0, 0.6], clamp),
      }}>
        <div style={{ color: GOLD, fontSize: 13, letterSpacing: 4, fontFamily: "'Noto Sans Telugu', sans-serif" }}>
          ★ &nbsp; NDA ప్రభుత్వం • ధర్మవరం నియోజకవర్గం &nbsp; ★
        </div>
      </div>
    </AbsoluteFill>
  );
};
