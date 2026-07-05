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

// ─── Text row animation types (6 distinct, cycling by row index) ─────────────
type RowAnim = "slideRight" | "slideLeft" | "slideUp" | "fadeScale" | "bounceRight" | "glowUp";
const ROW_ANIMS: RowAnim[] = ["slideRight", "slideLeft", "slideUp", "fadeScale", "bounceRight", "glowUp"];

const eOut = (x: number) => 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3);

// ─── Entry direction per tile based on its grid position ────────────────────
// Left-column tiles slide in from left, right-column from right,
// centre/single tiles from top or bottom — creates an "opening" look.
function getTileEntryDir(
  colIdx: number,
  rowLength: number,
  rowIdx: number
): "left" | "right" | "top" | "bottom" {
  if (rowLength === 1) return rowIdx % 2 === 0 ? "top" : "bottom";
  if (colIdx === 0) return "left";
  if (colIdx === rowLength - 1) return "right";
  return (rowIdx + colIdx) % 2 === 0 ? "top" : "bottom";
}

// ─── Ambient image transform (26 distinct per-scene Ken Burns styles) ────────
function getAmbientTransform(sceneIndex: number, frame: number): string {
  const si = ((sceneIndex % 26) + 26) % 26;
  const t = Math.min(frame / 420, 1); // normalise over scene duration

  switch (si) {
    // Zoom in
    case 0:  return `scale(${(1.0 + eOut(t) * 0.14).toFixed(4)})`;
    // Zoom out
    case 1:  return `scale(${(1.14 - eOut(t) * 0.14).toFixed(4)})`;
    // Snap-in then breathe
    case 9:  return `scale(${(1.0 + Math.max(0, 1 - t * 7) * 0.45).toFixed(4)})`;
    // Rapid snap-settle zoom-out
    case 13: return `scale(${Math.max(1.0, 1.65 - eOut(Math.min(t * 4, 1)) * 0.65).toFixed(4)})`;
    // Dramatic snap zoom-out
    case 25: return `scale(${Math.max(1.0, 2.2 - eOut(Math.min(t * 6, 1)) * 1.2).toFixed(4)})`;
    // Pan left
    case 2:  return `scale(1.10) translateX(${(t * -42).toFixed(1)}px)`;
    // Pan right
    case 3:  return `scale(1.10) translateX(${((t - 0.5) * 66).toFixed(1)}px)`;
    // Pan up
    case 4:  return `scale(1.10) translateY(${(t * -40).toFixed(1)}px)`;
    // Drift up
    case 7:  return `scale(1.07) translateY(${(-t * 34).toFixed(1)}px)`;
    // Drift down
    case 8:  return `scale(1.07) translateY(${(t * 34).toFixed(1)}px)`;
    // Slow pan up
    case 24: return `scale(1.08) translateY(${(-t * 48).toFixed(1)}px)`;
    // Diagonal zoom top-left
    case 5:  return `scale(${(1.0 + t * 0.14).toFixed(4)}) translateX(${(t * -26).toFixed(1)}px) translateY(${(t * -26).toFixed(1)}px)`;
    // Diagonal zoom bottom-right
    case 6:  return `scale(${(1.0 + t * 0.14).toFixed(4)}) translateX(${(t * 26).toFixed(1)}px) translateY(${(t * 26).toFixed(1)}px)`;
    // Diagonal zoom top-right
    case 14: return `scale(${(1.0 + t * 0.14).toFixed(4)}) translateX(${(t * 26).toFixed(1)}px) translateY(${(t * -26).toFixed(1)}px)`;
    // Diagonal zoom bottom-left
    case 15: return `scale(${(1.0 + t * 0.14).toFixed(4)}) translateX(${(t * -26).toFixed(1)}px) translateY(${(t * 26).toFixed(1)}px)`;
    // Zoom + gentle right drift
    case 23: return `scale(${(1.0 + eOut(t) * 0.12).toFixed(4)}) translateX(${(t * 22).toFixed(1)}px)`;
    // Rotate-correct left
    case 10: return `scale(${(1.10 - eOut(t) * 0.10).toFixed(4)}) rotate(${((1 - eOut(t)) * -4).toFixed(2)}deg)`;
    // Rotate-correct right
    case 11: return `scale(${(1.10 - eOut(t) * 0.10).toFixed(4)}) rotate(${((1 - eOut(t)) * 4).toFixed(2)}deg)`;
    // Wipe right then steady
    case 12: return `scale(1.10) translateX(${(-32 + t * 62).toFixed(1)}px)`;
    // Storm-settle left
    case 17: return `scale(${(1.12 - eOut(t) * 0.10).toFixed(4)}) translateX(${((1 - eOut(t)) * -30).toFixed(1)}px)`;
    // Fast snap then drift left
    case 22: return `scale(1.08) translateX(${((1 - eOut(Math.min(t * 5, 1))) * -70).toFixed(1)}px)`;
    // Storm-settle up
    case 21: return `scale(${(1.12 - eOut(t) * 0.10).toFixed(4)}) translateY(${(t * 30).toFixed(1)}px)`;
    // Breathe pulse
    case 16: return `scale(${(1.0 + Math.sin(t * Math.PI) * 0.08).toFixed(4)})`;
    // Wave float
    case 20: return `scale(1.05) translateY(${(Math.sin(t * Math.PI * 2) * 18).toFixed(1)}px)`;
    // Slow tilt-then-steady
    case 18: return `scale(1.05) rotate(${(t * 2.0 - 1.0).toFixed(2)}deg)`;
    // Slow tilt settle
    case 19: return `scale(${(1.0 + t * 0.10).toFixed(4)}) rotate(${((1 - t) * 0.65).toFixed(2)}deg)`;
    default: return `scale(${(1.0 + t * 0.08).toFixed(4)})`;
  }
}

// ─── PhotoTile ───────────────────────────────────────────────────────────────
const PhotoTile: React.FC<{
  src: string;
  delay: number;
  entryDir: "left" | "right" | "top" | "bottom";
  style?: CSSProperties;
  sceneIndex: number;
}> = ({ src, delay, entryDir, style, sceneIndex }) => {
  const frame = useCurrentFrame();

  const op = interpolate(frame, [delay, delay + 20], [0, 1], clamp);

  // Entry slide — 38-frame spring settle
  const tx =
    entryDir === "left"  ? interpolate(frame, [delay, delay + 28, delay + 36, delay + 42], [-90, 6, -3, 0], { ...clamp, easing: ez }) :
    entryDir === "right" ? interpolate(frame, [delay, delay + 28, delay + 36, delay + 42], [90, -6, 3, 0],  { ...clamp, easing: ez }) : 0;
  const ty =
    entryDir === "bottom" ? interpolate(frame, [delay, delay + 28, delay + 36, delay + 42], [80, -6, 3, 0],  { ...clamp, easing: ez }) :
    entryDir === "top"    ? interpolate(frame, [delay, delay + 28, delay + 36, delay + 42], [-80, 6, -3, 0], { ...clamp, easing: ez }) : 0;

  // Ambient Ken Burns starts as soon as entry finishes
  const ambientFrame = Math.max(0, frame - delay - 38);
  const ambientTransform = getAmbientTransform(sceneIndex, ambientFrame);

  // Gold border glow pulses after entry
  const glowOp = interpolate(
    frame,
    [delay + 38, delay + 70, delay + 160, delay + 240],
    [0, 0.9, 0.55, 0.72],
    clamp
  );

  return (
    <div
      style={{
        // Accept all flex sizing from parent; do NOT override flexShrink here
        ...style,
        opacity: op,
        transform: `translate(${tx}px, ${ty}px)`,
        overflow: "hidden",
        borderRadius: 12,
        background: "#0a1020",
        boxShadow: `0 14px 52px rgba(0,0,0,0.8), 0 0 0 2px ${GOLD}, 0 0 24px rgba(201,162,39,${glowOp.toFixed(2)})`,
        position: "relative",
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",            // fills tile completely — no dark bars
          objectPosition: "center 20%",  // favour top of image (faces, key content)
          transform: ambientTransform,   // Ken Burns ambient animation
          transformOrigin: "center center",
          display: "block",
        }}
      />
      {/* Inner inset gold frame on top of image */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          boxShadow: `inset 0 0 0 2px rgba(201,162,39,0.45)`,
          borderRadius: 10,
          pointerEvents: "none",
        }}
      />
    </div>
  );
};

// ─── StatRow — 6 distinct font animation types ───────────────────────────────
const StatRow: React.FC<{ label: string; value?: string; delay: number; index: number }> = ({
  label,
  value,
  delay,
  index,
}) => {
  const frame = useCurrentFrame();
  const anim = ROW_ANIMS[index % ROW_ANIMS.length];

  const op = interpolate(frame, [delay, delay + 18], [0, 1], clamp);

  let tx = 0, ty = 0, sc = 1;
  switch (anim) {
    case "slideRight":
      tx = interpolate(frame, [delay, delay + 26], [52, 0], { ...clamp, easing: ez });
      break;
    case "slideLeft":
      tx = interpolate(frame, [delay, delay + 26], [-52, 0], { ...clamp, easing: ez });
      break;
    case "slideUp":
      ty = interpolate(frame, [delay, delay + 26], [32, 0], { ...clamp, easing: ez });
      break;
    case "fadeScale":
      sc = interpolate(frame, [delay, delay + 26], [0.74, 1.0], clamp);
      break;
    case "bounceRight":
      tx = interpolate(
        frame,
        [delay, delay + 16, delay + 26, delay + 34],
        [60, -10, 4, 0],
        clamp
      );
      break;
    case "glowUp":
      ty = interpolate(frame, [delay, delay + 26], [24, 0], { ...clamp, easing: ez });
      break;
  }

  const valueGlow =
    anim === "glowUp"
      ? `0 0 ${interpolate(frame, [delay + 10, delay + 55], [24, 10], clamp).toFixed(1)}px rgba(201,162,39,0.75)`
      : "0 2px 14px rgba(201,162,39,0.45)";

  return (
    <div
      style={{
        opacity: op,
        transform: `translate(${tx}px, ${ty}px) scale(${sc})`,
        transformOrigin: "left center",
        marginBottom: value ? 20 : 14,
      }}
    >
      {value ? (
        <>
          <div
            style={{
              color: GOLD,
              fontSize: 30,
              fontWeight: 800,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              lineHeight: 1.2,
              textShadow: valueGlow,
            }}
          >
            {value}
          </div>
          <div
            style={{
              color: "#e8e8e8",
              fontSize: 18,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              lineHeight: 1.3,
              marginTop: 3,
            }}
          >
            {label}
          </div>
        </>
      ) : (
        <div
          style={{
            color: "#e8e8e8",
            fontSize: 18,
            fontFamily: "'Noto Sans Telugu', sans-serif",
            lineHeight: 1.45,
            paddingLeft: 16,
            borderLeft: `3px solid ${GOLD}`,
          }}
        >
          {label}
        </div>
      )}
    </div>
  );
};

// ─── DepartmentScene ─────────────────────────────────────────────────────────
export const DepartmentScene: React.FC<{ scene: SceneConfig; sceneIndex?: number }> = ({
  scene,
  sceneIndex = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const content = DEPT_CONTENT[scene.page];
  const images = content?.images ?? [];
  const hasImages = images.length >= 3;
  // Cap at 9 — pages with 9 images get a perfect 3×3 grid
  const displayImages = images.slice(0, 9);

  const fadeIn = interpolate(frame, [0, fps * 0.5], [0, 1], clamp);
  const fadeOut = interpolate(frame, [durationInFrames - fps * 0.6, durationInFrames], [1, 0], clamp);
  const opacity = Math.min(fadeIn, fadeOut);

  const bgScale = interpolate(frame, [0, durationInFrames], [1.0, 1.08], clamp);

  // ── Title entry animation — 6 types cycling per scene ─────────────────────
  const titleAnimType = ((sceneIndex % 6) + 6) % 6;
  const titleOp = interpolate(frame, [4, fps * 0.55], [0, 1], clamp);

  let titleTx = 0, titleTy = 0, titleSc = 1;
  switch (titleAnimType) {
    case 0: // slide down from top
      titleTy = interpolate(frame, [4, fps * 0.55], [-40, 0], { ...clamp, easing: ez });
      break;
    case 1: // slide from left
      titleTx = interpolate(frame, [4, fps * 0.55], [-80, 0], { ...clamp, easing: ez });
      break;
    case 2: // scale-in from centre
      titleSc = interpolate(frame, [4, fps * 0.6], [0.7, 1.0], clamp);
      break;
    case 3: // slide from right
      titleTx = interpolate(frame, [4, fps * 0.55], [80, 0], { ...clamp, easing: ez });
      break;
    case 4: // bounce up from bottom
      titleTy = interpolate(
        frame,
        [4, Math.round(fps * 0.42), Math.round(fps * 0.56), Math.round(fps * 0.68)],
        [55, -12, 5, 0],
        clamp
      );
      break;
    case 5: // diagonal (left + up)
      titleTx = interpolate(frame, [4, fps * 0.55], [-60, 0], { ...clamp, easing: ez });
      titleTy = interpolate(frame, [4, fps * 0.55], [-30, 0], { ...clamp, easing: ez });
      break;
  }

  const barW = interpolate(frame, [fps * 0.55, fps * 0.85], [0, hasImages ? 200 : 290], { ...clamp, easing: ez });
  const dividerH = interpolate(frame, [fps * 0.4, fps * 0.85], [0, 1], { ...clamp, easing: ez });
  const badgeOp = interpolate(frame, [fps * 0.8, fps * 1.2], [0, 1], clamp);

  const bgSrc = staticFile(`pages/page-${String(scene.page).padStart(2, "0")}.png`);

  const rightLeft = hasImages ? "57%" : "5%";
  const rightWidth = hasImages ? "39%" : "90%";

  // ── Build adaptive grid rows — window count = image count exactly ──────────
  type LayoutRow = {
    images: string[];
    flex: number;
    startGlobalIdx: number; // first global image index in this row
  };

  const buildRows = (): LayoutRow[] => {
    const di = displayImages;
    const n = di.length;
    if (n === 3) return [
      { images: di.slice(0, 1), flex: 2.0, startGlobalIdx: 0 },
      { images: di.slice(1, 3), flex: 1.4, startGlobalIdx: 1 },
    ];
    if (n === 4) return [
      { images: di.slice(0, 2), flex: 1, startGlobalIdx: 0 },
      { images: di.slice(2, 4), flex: 1, startGlobalIdx: 2 },
    ];
    if (n === 5) return [
      { images: di.slice(0, 1), flex: 2.0, startGlobalIdx: 0 },
      { images: di.slice(1, 3), flex: 1.2, startGlobalIdx: 1 },
      { images: di.slice(3, 5), flex: 1.2, startGlobalIdx: 3 },
    ];
    if (n === 6) return [
      { images: di.slice(0, 3), flex: 1, startGlobalIdx: 0 },
      { images: di.slice(3, 6), flex: 1, startGlobalIdx: 3 },
    ];
    if (n === 7) return [
      { images: di.slice(0, 1), flex: 1.8, startGlobalIdx: 0 },
      { images: di.slice(1, 4), flex: 1.1, startGlobalIdx: 1 },
      { images: di.slice(4, 7), flex: 1.1, startGlobalIdx: 4 },
    ];
    if (n === 8) return [
      { images: di.slice(0, 2), flex: 1.1, startGlobalIdx: 0 },
      { images: di.slice(2, 5), flex: 1.0, startGlobalIdx: 2 },
      { images: di.slice(5, 8), flex: 1.0, startGlobalIdx: 5 },
    ];
    // 9 → perfect 3×3
    return [
      { images: di.slice(0, 3), flex: 1, startGlobalIdx: 0 },
      { images: di.slice(3, 6), flex: 1, startGlobalIdx: 3 },
      { images: di.slice(6, 9), flex: 1, startGlobalIdx: 6 },
    ];
  };

  // Stagger delay per image: 12 frames between each
  const imgDelay = (globalIdx: number) => 8 + globalIdx * 14;

  return (
    <AbsoluteFill style={{ background: NAVY, overflow: "hidden", opacity }}>
      {/* ── Blurred page background ── */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `url(${bgSrc})`,
          backgroundSize: "cover",
          backgroundPosition: "center top",
          filter: "blur(30px) brightness(0.16)",
          transform: `scale(${bgScale})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "linear-gradient(135deg, rgba(10,22,40,0.75) 0%, rgba(10,22,40,0.35) 100%)",
        }}
      />

      {/* ── PHOTO PANEL ── */}
      {hasImages && (() => {
        const rows = buildRows();
        const gap = 8;
        return (
          <div
            style={{
              position: "absolute",
              left: 32,
              top: 0,
              bottom: 0,
              width: "55%",
              display: "flex",
              flexDirection: "column",
              justifyContent: "center",
              gap,
              padding: `44px ${gap}px 44px 0`,
            }}
          >
            {rows.map((row, rowIdx) => (
              <div
                key={rowIdx}
                style={{
                  display: "flex",
                  gap,
                  flex: row.flex,
                  minHeight: 0,
                }}
              >
                {row.images.map((src, colIdx) => {
                  const globalIdx = row.startGlobalIdx + colIdx;
                  const dir = getTileEntryDir(colIdx, row.images.length, rowIdx);
                  return (
                    <PhotoTile
                      key={src}
                      src={src}
                      delay={imgDelay(globalIdx)}
                      entryDir={dir}
                      sceneIndex={sceneIndex}
                      style={{
                        flex: 1,
                        minWidth: 0,
                        minHeight: 0,
                      }}
                    />
                  );
                })}
              </div>
            ))}
          </div>
        );
      })()}

      {/* ── Gold vertical divider ── */}
      {hasImages && (
        <div
          style={{
            position: "absolute",
            left: "57%",
            top: `${(1 - dividerH) * 50}%`,
            width: 2,
            height: `${dividerH * 84}%`,
            background: `linear-gradient(to bottom, transparent, ${GOLD}, transparent)`,
          }}
        />
      )}

      {/* ── TEXT PANEL ── */}
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
          paddingRight: hasImages ? 44 : 80,
          paddingLeft: hasImages ? 26 : 80,
        }}
      >
        {/* Title block — animated entry */}
        <div
          style={{
            opacity: titleOp,
            transform: `translate(${titleTx}px, ${titleTy}px) scale(${titleSc})`,
            transformOrigin: "left center",
            marginBottom: 22,
          }}
        >
          <div
            style={{
              color: GOLD,
              fontSize: 13,
              letterSpacing: 3.5,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              marginBottom: 7,
              textTransform: "uppercase",
            }}
          >
            {content?.titleEnglish ?? ""}
          </div>
          <div
            style={{
              color: "#ffffff",
              fontSize: hasImages ? 34 : 44,
              fontWeight: 800,
              fontFamily: "'Noto Sans Telugu', sans-serif",
              lineHeight: 1.2,
              textShadow: "0 4px 22px rgba(0,0,0,0.65)",
            }}
          >
            {content?.titleTelugu ?? ""}
          </div>
          {/* Animated gold underbar */}
          <div
            style={{
              width: barW,
              height: 3,
              background: `linear-gradient(to right, ${GOLD}, rgba(201,162,39,0.3))`,
              marginTop: 12,
              borderRadius: 2,
            }}
          />
        </div>

        {/* Highlights — each row uses a different font animation */}
        <div style={{ display: "flex", flexDirection: "column" }}>
          {content?.highlights.map((h, i) => (
            <StatRow
              key={i}
              label={h.label}
              value={h.value}
              delay={fps * 0.65 + i * 15}
              index={i}
            />
          ))}
        </div>
      </div>

      {/* ── Footer badge ── */}
      <div
        style={{
          position: "absolute",
          bottom: 24,
          right: 40,
          opacity: badgeOp,
          background: "rgba(201,162,39,0.12)",
          border: "1px solid rgba(201,162,39,0.35)",
          borderRadius: 6,
          padding: "6px 16px",
          color: GOLD,
          fontSize: 13,
          fontFamily: "'Noto Sans Telugu', sans-serif",
          letterSpacing: 2,
        }}
      >
        ★ ధర్మవరం నియోజకవర్గం • 2024–2026 ★
      </div>
    </AbsoluteFill>
  );
};
