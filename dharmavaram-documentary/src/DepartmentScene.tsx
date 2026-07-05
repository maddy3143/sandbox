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
import { DEPT_CONTENT } from "./data/deptContent";
import type { SceneConfig } from "./data/scenes";

const GOLD = "#C9A227";
const NAVY = "#0A1628";
const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };
const ez = Easing.bezier(0.16, 1, 0.3, 1);

// 26 entry directions — cycles once per dept scene so adjacent tiles always differ
const ENTRY_DIRS: Array<"left" | "right" | "bottom" | "top"> = [
  "left",   "bottom", "top",    "right",  "left",
  "bottom", "top",    "right",  "left",   "bottom",
  "top",    "right",  "left",   "bottom", "top",
  "right",  "left",   "bottom", "top",    "right",
  "left",   "bottom", "top",    "right",  "left",
  "bottom",
];

// easeOutCubic helper
const eOut = (x: number) => 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3);

/**
 * 26 distinct ambient image transforms — one per department scene.
 * `frame` is frames elapsed *after* the tile has fully entered (entry settle).
 */
function getAmbientTransform(sceneIndex: number, frame: number): string {
  const si = ((sceneIndex % 26) + 26) % 26;
  const t = Math.min(frame / 450, 1); // progress 0→1 over 15 s scene

  switch (si) {
    // ── Zoom family ──────────────────────────────────────────────────────────
    case 0:  return `scale(${(1.0 + eOut(t) * 0.13).toFixed(4)})`; // slow zoom in
    case 1:  return `scale(${(1.13 - eOut(t) * 0.13).toFixed(4)})`; // slow zoom out
    case 9:  return `scale(${(1.0 + Math.max(0, 1 - t * 7) * 0.42).toFixed(4)})`; // snap settle
    case 13: return `scale(${Math.max(1.0, 1.65 - eOut(Math.min(t * 4, 1)) * 0.65).toFixed(4)})`; // depth push
    case 25: return `scale(${Math.max(1.0, 2.2 - eOut(Math.min(t * 6, 1)) * 1.2).toFixed(4)})`; // storm settle

    // ── Pan family ───────────────────────────────────────────────────────────
    case 2:  return `scale(1.09) translateX(${(t * -38).toFixed(1)}px)`; // pan left
    case 3:  return `scale(1.09) translateX(${((t - 0.5) * 62).toFixed(1)}px)`; // pan right
    case 4:  return `scale(1.09) translateY(${(t * -38).toFixed(1)}px)`; // pan up
    case 7:  return `scale(1.05) translateY(${(-t * 32).toFixed(1)}px)`; // float up
    case 8:  return `scale(1.05) translateY(${(t * 32).toFixed(1)}px)`; // float down
    case 24: return `scale(1.07) translateY(${(-t * 44).toFixed(1)}px)`; // float fast

    // ── Ken Burns diagonals ───────────────────────────────────────────────────
    case 5:  return `scale(${(1.0 + t * 0.13).toFixed(4)}) translateX(${(t * -24).toFixed(1)}px) translateY(${(t * -24).toFixed(1)}px)`; // kb top-right
    case 6:  return `scale(${(1.0 + t * 0.13).toFixed(4)}) translateX(${(t * 24).toFixed(1)}px) translateY(${(t * 24).toFixed(1)}px)`;  // kb bot-left
    case 14: return `scale(${(1.0 + t * 0.13).toFixed(4)}) translateX(${(t * 24).toFixed(1)}px) translateY(${(t * -24).toFixed(1)}px)`; // kb top-left
    case 15: return `scale(${(1.0 + t * 0.13).toFixed(4)}) translateX(${(t * -24).toFixed(1)}px) translateY(${(t * 24).toFixed(1)}px)`;  // kb bot-right
    case 23: return `scale(${(1.0 + eOut(t) * 0.1).toFixed(4)}) translateX(${(t * 20).toFixed(1)}px)`; // kb alt

    // ── Tilt corrections ─────────────────────────────────────────────────────
    case 10: return `scale(${(1.09 - eOut(t) * 0.09).toFixed(4)}) rotate(${((1 - eOut(t)) * -3.5).toFixed(2)}deg)`; // tilt left
    case 11: return `scale(${(1.09 - eOut(t) * 0.09).toFixed(4)}) rotate(${((1 - eOut(t)) * 3.5).toFixed(2)}deg)`;  // tilt right

    // ── Drift / slide ────────────────────────────────────────────────────────
    case 12: return `scale(1.09) translateX(${(-30 + t * 62).toFixed(1)}px)`; // drift right
    case 17: return `scale(${(1.11 - eOut(t) * 0.09).toFixed(4)}) translateX(${((1 - eOut(t)) * -28).toFixed(1)}px)`; // slide-zoom
    case 22: return `scale(1.07) translateX(${((1 - eOut(Math.min(t * 5, 1))) * -65).toFixed(1)}px)`; // fast pan settle
    case 21: return `scale(${(1.12 - eOut(t) * 0.12).toFixed(4)}) translateY(${(t * 28).toFixed(1)}px)`; // zoom-pan down

    // ── Organic / oscillate ───────────────────────────────────────────────────
    case 16: return `scale(${(1.0 + Math.sin(t * Math.PI) * 0.065).toFixed(4)})`; // breathe (half period)
    case 18: return `scale(1.05) rotate(${(t * 1.8 - 0.9).toFixed(2)}deg)`; // revolve
    case 19: return `scale(${(1.0 + t * 0.09).toFixed(4)}) rotate(${((1 - t) * 0.6).toFixed(2)}deg)`; // cinematic
    case 20: return `scale(1.05) translateY(${(Math.sin(t * Math.PI * 2) * 16).toFixed(1)}px)`; // wave float

    default: return `scale(${(1.0 + t * 0.07).toFixed(4)})`;
  }
}

// ─── PhotoTile ──────────────────────────────────────────────────────────────

const PhotoTile: React.FC<{
  src: string;
  delay: number;
  style?: CSSProperties;
  sceneIndex: number;
  tileIndex?: number;
}> = ({ src, delay, style, sceneIndex, tileIndex = 0 }) => {
  const frame = useCurrentFrame();

  const entryDir = ENTRY_DIRS[((sceneIndex % 26) + 26) % 26];

  // Fade-in
  const op = interpolate(frame, [delay, delay + 22], [0, 1], clamp);

  // Entry slide (container moves, overflow:hidden clips the inner image)
  const tx =
    entryDir === "left"  ? interpolate(frame, [delay, delay + 32], [-90, 0], { ...clamp, easing: ez }) :
    entryDir === "right" ? interpolate(frame, [delay, delay + 32], [90, 0],  { ...clamp, easing: ez }) : 0;
  const ty =
    entryDir === "bottom" ? interpolate(frame, [delay, delay + 32], [90, 0],  { ...clamp, easing: ez }) :
    entryDir === "top"    ? interpolate(frame, [delay, delay + 32], [-90, 0], { ...clamp, easing: ez }) : 0;

  // Ambient motion starts after tile has settled (delay + 30 frames)
  const ambientFrame = Math.max(0, frame - delay - 30);
  const ambientTransform = getAmbientTransform(sceneIndex, ambientFrame);

  // Staggered golden border glow pulse
  const glowOp = interpolate(
    frame,
    [delay + 30, delay + 60, delay + 120, delay + 180],
    [0, 0.8, 0.5, 0.65],
    clamp
  );

  return (
    <div
      style={{
        ...style,
        opacity: op,
        transform: `translate(${tx}px, ${ty}px)`,
        overflow: "hidden",
        borderRadius: 10,
        boxShadow: `0 12px 48px rgba(0,0,0,0.75), 0 0 0 2px ${GOLD}, 0 0 18px rgba(201,162,39,${glowOp.toFixed(2)})`,
        position: "relative",
        flexShrink: 0,
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: "center 25%",  // bias upward to keep faces in frame
          transform: ambientTransform,
          transformOrigin: "center center",
          display: "block",
        }}
      />
      {/* Inner gold frame overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          boxShadow: `inset 0 0 0 2px rgba(201,162,39,0.55)`,
          borderRadius: 8,
          pointerEvents: "none",
        }}
      />
    </div>
  );
};

// ─── StatRow ────────────────────────────────────────────────────────────────

const StatRow: React.FC<{ label: string; value?: string; delay: number; index: number }> = ({
  label,
  value,
  delay,
}) => {
  const frame = useCurrentFrame();
  const op = interpolate(frame, [delay, delay + 18], [0, 1], clamp);
  const tx = interpolate(frame, [delay, delay + 25], [40, 0], { ...clamp, easing: ez });

  return (
    <div style={{ opacity: op, transform: `translateX(${tx}px)`, marginBottom: value ? 18 : 14 }}>
      {value ? (
        <>
          <div
            style={{
              color: GOLD,
              fontSize: 24,
              fontWeight: 800,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              lineHeight: 1.2,
              textShadow: "0 2px 12px rgba(201,162,39,0.4)",
            }}
          >
            {value}
          </div>
          <div
            style={{
              color: "#e0e0e0",
              fontSize: 15,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              lineHeight: 1.3,
              marginTop: 2,
            }}
          >
            {label}
          </div>
        </>
      ) : (
        <div
          style={{
            color: "#e0e0e0",
            fontSize: 15,
            fontFamily: "'Noto Sans Telugu', sans-serif",
            lineHeight: 1.4,
            paddingLeft: 14,
            borderLeft: `3px solid ${GOLD}`,
          }}
        >
          {label}
        </div>
      )}
    </div>
  );
};

// ─── DepartmentScene ────────────────────────────────────────────────────────

export const DepartmentScene: React.FC<{ scene: SceneConfig; sceneIndex?: number }> = ({
  scene,
  sceneIndex = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const content = DEPT_CONTENT[scene.page];
  const images = content?.images ?? [];
  // Only show photo panel when ≥ 3 images are available
  const hasImages = images.length >= 3;

  const fadeIn = interpolate(frame, [0, fps * 0.5], [0, 1], clamp);
  const fadeOut = interpolate(frame, [durationInFrames - fps * 0.6, durationInFrames], [1, 0], clamp);
  const opacity = Math.min(fadeIn, fadeOut);

  const bgScale = interpolate(frame, [0, durationInFrames], [1.0, 1.08], clamp);
  const titleOp = interpolate(frame, [5, fps * 0.6], [0, 1], { ...clamp, easing: ez });
  const titleY = interpolate(frame, [5, fps * 0.6], [-30, 0], { ...clamp, easing: ez });
  const barW = interpolate(frame, [fps * 0.6, fps * 0.9], [0, hasImages ? 180 : 260], { ...clamp, easing: ez });
  const dividerH = interpolate(frame, [fps * 0.4, fps * 0.9], [0, 1], { ...clamp, easing: ez });
  const badgeOp = interpolate(frame, [fps * 0.8, fps * 1.2], [0, 1], clamp);

  const bgSrc = staticFile(`pages/page-${String(scene.page).padStart(2, "0")}.png`);

  const rightLeft = hasImages ? "56%" : "5%";
  const rightWidth = hasImages ? "40%" : "90%";

  // Tile delays — staggered by 14 frames each
  const tileDelays = [8, 22, 36, 50];

  return (
    <AbsoluteFill style={{ background: NAVY, overflow: "hidden", opacity }}>
      {/* Blurred background */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `url(${bgSrc})`,
          backgroundSize: "cover",
          backgroundPosition: "center top",
          filter: "blur(28px) brightness(0.18)",
          transform: `scale(${bgScale})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "linear-gradient(135deg, rgba(10,22,40,0.72) 0%, rgba(10,22,40,0.38) 100%)",
        }}
      />

      {/* ── PHOTO PANEL (left 52%) ── */}
      {hasImages && (
        <div
          style={{
            position: "absolute",
            left: 40,
            top: 0,
            bottom: 0,
            width: "52%",
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            gap: 12,
            padding: "60px 20px 60px 0",
          }}
        >
          {images.length === 3 && (
            <>
              <PhotoTile
                src={images[0]} delay={tileDelays[0]} sceneIndex={sceneIndex} tileIndex={0}
                style={{ height: 280, width: "100%" }}
              />
              <div style={{ display: "flex", gap: 12, flex: 1 }}>
                <PhotoTile src={images[1]} delay={tileDelays[1]} sceneIndex={sceneIndex} tileIndex={1} style={{ flex: 1, height: 260 }} />
                <PhotoTile src={images[2]} delay={tileDelays[2]} sceneIndex={sceneIndex} tileIndex={2} style={{ flex: 1, height: 260 }} />
              </div>
            </>
          )}
          {images.length >= 4 && (
            <>
              <PhotoTile
                src={images[0]} delay={tileDelays[0]} sceneIndex={sceneIndex} tileIndex={0}
                style={{ height: 270, width: "100%" }}
              />
              <div style={{ display: "flex", gap: 12, flex: 1 }}>
                <PhotoTile src={images[1]} delay={tileDelays[1]} sceneIndex={sceneIndex} tileIndex={1} style={{ flex: 1, height: 260 }} />
                <PhotoTile src={images[2]} delay={tileDelays[2]} sceneIndex={sceneIndex} tileIndex={2} style={{ flex: 1, height: 260 }} />
                {images[3] && (
                  <PhotoTile src={images[3]} delay={tileDelays[3]} sceneIndex={sceneIndex} tileIndex={3} style={{ flex: 1, height: 260 }} />
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* ── GOLD DIVIDER ── */}
      {hasImages && (
        <div
          style={{
            position: "absolute",
            left: "55.5%",
            top: `${(1 - dividerH) * 50}%`,
            width: 2,
            height: `${dividerH * 84}%`,
            background: `linear-gradient(to bottom, transparent, ${GOLD}, transparent)`,
          }}
        />
      )}

      {/* ── TEXT PANEL (right) ── */}
      <div
        style={{
          position: "absolute",
          left: rightLeft,
          width: rightWidth,
          top: 0,
          bottom: 0,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          paddingRight: hasImages ? 50 : 80,
          paddingLeft: hasImages ? 28 : 80,
        }}
      >
        {/* Title */}
        <div style={{ opacity: titleOp, transform: `translateY(${titleY}px)`, marginBottom: 22 }}>
          <div
            style={{
              color: GOLD,
              fontSize: 12,
              letterSpacing: 3,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              marginBottom: 6,
              textTransform: "uppercase",
            }}
          >
            {content?.titleEnglish ?? ""}
          </div>
          <div
            style={{
              color: "#ffffff",
              fontSize: hasImages ? 28 : 36,
              fontWeight: 800,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              lineHeight: 1.2,
              textShadow: "0 4px 20px rgba(0,0,0,0.6)",
            }}
          >
            {content?.titleTelugu ?? ""}
          </div>
          <div style={{ width: barW, height: 3, background: GOLD, marginTop: 10, borderRadius: 2 }} />
        </div>

        {/* Highlights */}
        <div style={{ display: "flex", flexDirection: "column" }}>
          {content?.highlights.map((h, i) => (
            <StatRow key={i} label={h.label} value={h.value} delay={fps * 0.7 + i * 12} index={i} />
          ))}
        </div>
      </div>

      {/* Footer badge */}
      <div
        style={{
          position: "absolute",
          bottom: 24,
          right: 40,
          opacity: badgeOp,
          background: "rgba(201,162,39,0.12)",
          border: "1px solid rgba(201,162,39,0.35)",
          borderRadius: 6,
          padding: "5px 14px",
          color: GOLD,
          fontSize: 12,
          fontFamily: "'Noto Sans Telugu', sans-serif",
          letterSpacing: 2,
        }}
      >
        ★ ధర్మవరం నియోజకవర్గం • 2024–2026 ★
      </div>
    </AbsoluteFill>
  );
};
