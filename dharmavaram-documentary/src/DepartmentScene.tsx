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

// ─── Entry directions for image tiles — cycles per scene ────────────────────
const ENTRY_DIRS: Array<"left" | "right" | "bottom" | "top"> = [
  "left",   "bottom", "top",    "right",  "left",
  "bottom", "top",    "right",  "left",   "bottom",
  "top",    "right",  "left",   "bottom", "top",
  "right",  "left",   "bottom", "top",    "right",
  "left",   "bottom", "top",    "right",  "left",
  "bottom",
];

// ─── Text row animation types (6 distinct) ───────────────────────────────────
type RowAnim = "slideRight" | "slideLeft" | "slideUp" | "fadeScale" | "bounceRight" | "glowUp";
const ROW_ANIMS: RowAnim[] = ["slideRight", "slideLeft", "slideUp", "fadeScale", "bounceRight", "glowUp"];

const eOut = (x: number) => 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3);

// ─── Ambient image transform (26 distinct per-scene styles) ─────────────────
function getAmbientTransform(sceneIndex: number, frame: number): string {
  const si = ((sceneIndex % 26) + 26) % 26;
  const t = Math.min(frame / 450, 1);

  switch (si) {
    case 0:  return `scale(${(1.0 + eOut(t) * 0.12).toFixed(4)})`;
    case 1:  return `scale(${(1.12 - eOut(t) * 0.12).toFixed(4)})`;
    case 9:  return `scale(${(1.0 + Math.max(0, 1 - t * 7) * 0.40).toFixed(4)})`;
    case 13: return `scale(${Math.max(1.0, 1.60 - eOut(Math.min(t * 4, 1)) * 0.60).toFixed(4)})`;
    case 25: return `scale(${Math.max(1.0, 2.1 - eOut(Math.min(t * 6, 1)) * 1.1).toFixed(4)})`;
    case 2:  return `scale(1.08) translateX(${(t * -36).toFixed(1)}px)`;
    case 3:  return `scale(1.08) translateX(${((t - 0.5) * 58).toFixed(1)}px)`;
    case 4:  return `scale(1.08) translateY(${(t * -36).toFixed(1)}px)`;
    case 7:  return `scale(1.05) translateY(${(-t * 30).toFixed(1)}px)`;
    case 8:  return `scale(1.05) translateY(${(t * 30).toFixed(1)}px)`;
    case 24: return `scale(1.06) translateY(${(-t * 42).toFixed(1)}px)`;
    case 5:  return `scale(${(1.0 + t * 0.12).toFixed(4)}) translateX(${(t * -22).toFixed(1)}px) translateY(${(t * -22).toFixed(1)}px)`;
    case 6:  return `scale(${(1.0 + t * 0.12).toFixed(4)}) translateX(${(t * 22).toFixed(1)}px) translateY(${(t * 22).toFixed(1)}px)`;
    case 14: return `scale(${(1.0 + t * 0.12).toFixed(4)}) translateX(${(t * 22).toFixed(1)}px) translateY(${(t * -22).toFixed(1)}px)`;
    case 15: return `scale(${(1.0 + t * 0.12).toFixed(4)}) translateX(${(t * -22).toFixed(1)}px) translateY(${(t * 22).toFixed(1)}px)`;
    case 23: return `scale(${(1.0 + eOut(t) * 0.10).toFixed(4)}) translateX(${(t * 18).toFixed(1)}px)`;
    case 10: return `scale(${(1.08 - eOut(t) * 0.08).toFixed(4)}) rotate(${((1 - eOut(t)) * -3.5).toFixed(2)}deg)`;
    case 11: return `scale(${(1.08 - eOut(t) * 0.08).toFixed(4)}) rotate(${((1 - eOut(t)) * 3.5).toFixed(2)}deg)`;
    case 12: return `scale(1.08) translateX(${(-28 + t * 58).toFixed(1)}px)`;
    case 17: return `scale(${(1.10 - eOut(t) * 0.08).toFixed(4)}) translateX(${((1 - eOut(t)) * -26).toFixed(1)}px)`;
    case 22: return `scale(1.06) translateX(${((1 - eOut(Math.min(t * 5, 1))) * -62).toFixed(1)}px)`;
    case 21: return `scale(${(1.10 - eOut(t) * 0.10).toFixed(4)}) translateY(${(t * 26).toFixed(1)}px)`;
    case 16: return `scale(${(1.0 + Math.sin(t * Math.PI) * 0.06).toFixed(4)})`;
    case 18: return `scale(1.04) rotate(${(t * 1.8 - 0.9).toFixed(2)}deg)`;
    case 19: return `scale(${(1.0 + t * 0.08).toFixed(4)}) rotate(${((1 - t) * 0.55).toFixed(2)}deg)`;
    case 20: return `scale(1.04) translateY(${(Math.sin(t * Math.PI * 2) * 15).toFixed(1)}px)`;
    default: return `scale(${(1.0 + t * 0.06).toFixed(4)})`;
  }
}

// ─── PhotoTile ───────────────────────────────────────────────────────────────

const PhotoTile: React.FC<{
  src: string;
  delay: number;
  style?: CSSProperties;
  sceneIndex: number;
  tileIndex?: number;
}> = ({ src, delay, style, sceneIndex, tileIndex = 0 }) => {
  const frame = useCurrentFrame();

  const entryDir = ENTRY_DIRS[((sceneIndex % 26) + 26) % 26];

  const op = interpolate(frame, [delay, delay + 22], [0, 1], clamp);
  const tx =
    entryDir === "left"  ? interpolate(frame, [delay, delay + 34], [-100, 0], { ...clamp, easing: ez }) :
    entryDir === "right" ? interpolate(frame, [delay, delay + 34], [100, 0],  { ...clamp, easing: ez }) : 0;
  const ty =
    entryDir === "bottom" ? interpolate(frame, [delay, delay + 34], [100, 0],  { ...clamp, easing: ez }) :
    entryDir === "top"    ? interpolate(frame, [delay, delay + 34], [-100, 0], { ...clamp, easing: ez }) : 0;

  const ambientFrame = Math.max(0, frame - delay - 30);
  const ambientTransform = getAmbientTransform(sceneIndex, ambientFrame);

  const glowOp = interpolate(frame, [delay + 30, delay + 60, delay + 140, delay + 200], [0, 0.85, 0.5, 0.65], clamp);

  return (
    <div
      style={{
        ...style,
        opacity: op,
        transform: `translate(${tx}px, ${ty}px)`,
        overflow: "hidden",
        borderRadius: 12,
        // Dark fill so letterbox areas from objectFit:contain blend with design
        background: "rgba(4,10,22,0.92)",
        boxShadow: `0 14px 52px rgba(0,0,0,0.8), 0 0 0 2px ${GOLD}, 0 0 22px rgba(201,162,39,${glowOp.toFixed(2)})`,
        position: "relative",
        flexShrink: 0,
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          width: "100%",
          height: "100%",
          // contain = full image always visible, no cropping
          objectFit: "contain",
          objectPosition: "center center",
          transform: ambientTransform,
          transformOrigin: "center center",
          display: "block",
        }}
      />
      {/* Inner gold inset frame */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          boxShadow: `inset 0 0 0 2px rgba(201,162,39,0.5)`,
          borderRadius: 10,
          pointerEvents: "none",
        }}
      />
    </div>
  );
};

// ─── StatRow — 6 distinct animation types cycling by row index ───────────────

const StatRow: React.FC<{ label: string; value?: string; delay: number; index: number }> = ({
  label,
  value,
  delay,
  index,
}) => {
  const frame = useCurrentFrame();
  const anim = ROW_ANIMS[index % ROW_ANIMS.length];

  const op = interpolate(frame, [delay, delay + 20], [0, 1], clamp);

  let tx = 0, ty = 0, sc = 1;
  switch (anim) {
    case "slideRight":
      tx = interpolate(frame, [delay, delay + 28], [50, 0], { ...clamp, easing: ez });
      break;
    case "slideLeft":
      tx = interpolate(frame, [delay, delay + 28], [-50, 0], { ...clamp, easing: ez });
      break;
    case "slideUp":
      ty = interpolate(frame, [delay, delay + 28], [30, 0], { ...clamp, easing: ez });
      break;
    case "fadeScale":
      sc = interpolate(frame, [delay, delay + 28], [0.78, 1.0], clamp);
      break;
    case "bounceRight":
      // spring: overshoot from right then settle
      tx = interpolate(
        frame,
        [delay, delay + 18, delay + 27, delay + 34],
        [55, -9, 3, 0],
        clamp
      );
      break;
    case "glowUp":
      ty = interpolate(frame, [delay, delay + 28], [22, 0], { ...clamp, easing: ez });
      break;
  }

  const valueGlow = anim === "glowUp"
    ? `0 0 ${interpolate(frame, [delay + 10, delay + 50], [22, 10], clamp).toFixed(1)}px rgba(201,162,39,0.7)`
    : "0 2px 14px rgba(201,162,39,0.4)";

  return (
    <div
      style={{
        opacity: op,
        transform: `translate(${tx}px, ${ty}px) scale(${sc})`,
        transformOrigin: "left center",
        marginBottom: value ? 22 : 16,
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
  // Show up to 9 images; 9 gets a perfect 3×3 grid
  const displayImages = images.slice(0, 9);

  const fadeIn = interpolate(frame, [0, fps * 0.5], [0, 1], clamp);
  const fadeOut = interpolate(frame, [durationInFrames - fps * 0.6, durationInFrames], [1, 0], clamp);
  const opacity = Math.min(fadeIn, fadeOut);

  const bgScale = interpolate(frame, [0, durationInFrames], [1.0, 1.08], clamp);

  // ── Title entry: 6 styles cycling per scene ──────────────────────────────
  const titleAnimType = ((sceneIndex % 6) + 6) % 6;
  const titleOp = interpolate(frame, [5, fps * 0.6], [0, 1], clamp);

  let titleTx = 0, titleTy = 0, titleSc = 1;
  switch (titleAnimType) {
    case 0: // slide from top
      titleTy = interpolate(frame, [5, fps * 0.6], [-38, 0], { ...clamp, easing: ez });
      break;
    case 1: // slide from left
      titleTx = interpolate(frame, [5, fps * 0.6], [-75, 0], { ...clamp, easing: ez });
      break;
    case 2: // scale in
      titleSc = interpolate(frame, [5, fps * 0.65], [0.75, 1.0], clamp);
      break;
    case 3: // slide from right
      titleTx = interpolate(frame, [5, fps * 0.6], [75, 0], { ...clamp, easing: ez });
      break;
    case 4: // bounce from bottom
      titleTy = interpolate(
        frame,
        [5, Math.round(fps * 0.45), Math.round(fps * 0.6), Math.round(fps * 0.72)],
        [50, -11, 4, 0],
        clamp
      );
      break;
    case 5: // diagonal slide (left + up)
      titleTx = interpolate(frame, [5, fps * 0.6], [-55, 0], { ...clamp, easing: ez });
      titleTy = interpolate(frame, [5, fps * 0.6], [-28, 0], { ...clamp, easing: ez });
      break;
  }

  const barW = interpolate(frame, [fps * 0.6, fps * 0.9], [0, hasImages ? 200 : 280], { ...clamp, easing: ez });
  const dividerH = interpolate(frame, [fps * 0.4, fps * 0.9], [0, 1], { ...clamp, easing: ez });
  const badgeOp = interpolate(frame, [fps * 0.8, fps * 1.2], [0, 1], clamp);

  const bgSrc = staticFile(`pages/page-${String(scene.page).padStart(2, "0")}.png`);

  const rightLeft = hasImages ? "57%" : "5%";
  const rightWidth = hasImages ? "39%" : "90%";

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

      {/* ── PHOTO PANEL (left 55%) — adaptive grid per image count ── */}
      {hasImages && (() => {
        const di = displayImages;
        const n = di.length;
        const gap = 8;
        const delays = [6, 18, 30, 42, 54, 66, 78, 90, 102];

        // Build rows depending on count:
        //  3 → [top] + [2]              featured top, 2-wide row
        //  4 → [2] + [2]               clean 2×2 grid
        //  5 → [top] + [2] + [2]       featured + two 2-wide rows
        //  6 → [3] + [3]               clean 2×3 grid
        //  7 → [top] + [3] + [3]       featured + two 3-wide rows
        //  8 → [2] + [3] + [3]         2 on top + 3+3 below
        //  9 → [3] + [3] + [3]         perfect 3×3 grid
        type LayoutRow = { images: string[]; flex: number; startIdx: number };
        const rows: LayoutRow[] = [];

        if (n === 3) {
          rows.push({ images: di.slice(0, 1), flex: 2.0, startIdx: 0 });
          rows.push({ images: di.slice(1, 3), flex: 1.4, startIdx: 1 });
        } else if (n === 4) {
          rows.push({ images: di.slice(0, 2), flex: 1, startIdx: 0 });
          rows.push({ images: di.slice(2, 4), flex: 1, startIdx: 2 });
        } else if (n === 5) {
          rows.push({ images: di.slice(0, 1), flex: 2.0, startIdx: 0 });
          rows.push({ images: di.slice(1, 3), flex: 1.2, startIdx: 1 });
          rows.push({ images: di.slice(3, 5), flex: 1.2, startIdx: 3 });
        } else if (n === 6) {
          rows.push({ images: di.slice(0, 3), flex: 1, startIdx: 0 });
          rows.push({ images: di.slice(3, 6), flex: 1, startIdx: 3 });
        } else if (n === 7) {
          rows.push({ images: di.slice(0, 1), flex: 1.8, startIdx: 0 });
          rows.push({ images: di.slice(1, 4), flex: 1.1, startIdx: 1 });
          rows.push({ images: di.slice(4, 7), flex: 1.1, startIdx: 4 });
        } else if (n === 8) {
          rows.push({ images: di.slice(0, 2), flex: 1.1, startIdx: 0 });
          rows.push({ images: di.slice(2, 5), flex: 1, startIdx: 2 });
          rows.push({ images: di.slice(5, 8), flex: 1, startIdx: 5 });
        } else {
          // 9 → 3×3
          rows.push({ images: di.slice(0, 3), flex: 1, startIdx: 0 });
          rows.push({ images: di.slice(3, 6), flex: 1, startIdx: 3 });
          rows.push({ images: di.slice(6, 9), flex: 1, startIdx: 6 });
        }

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
              <div key={rowIdx} style={{ display: "flex", gap, flex: row.flex, minHeight: 0 }}>
                {row.images.map((src, colIdx) => (
                  <PhotoTile
                    key={src}
                    src={src}
                    delay={delays[row.startIdx + colIdx] ?? 8}
                    sceneIndex={sceneIndex}
                    tileIndex={row.startIdx + colIdx}
                    style={{ flex: 1, minWidth: 0, minHeight: 0 }}
                  />
                ))}
              </div>
            ))}
          </div>
        );
      })()}

      {/* ── GOLD DIVIDER ── */}
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
          paddingRight: hasImages ? 44 : 80,
          paddingLeft: hasImages ? 26 : 80,
        }}
      >
        {/* Title with per-scene entry animation */}
        <div
          style={{
            opacity: titleOp,
            transform: `translate(${titleTx}px, ${titleTy}px) scale(${titleSc})`,
            transformOrigin: "left center",
            marginBottom: 24,
          }}
        >
          <div
            style={{
              color: GOLD,
              fontSize: 14,
              letterSpacing: 3,
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
          <div style={{ width: barW, height: 3, background: GOLD, marginTop: 12, borderRadius: 2 }} />
        </div>

        {/* Highlights — each row gets a different animation */}
        <div style={{ display: "flex", flexDirection: "column" }}>
          {content?.highlights.map((h, i) => (
            <StatRow
              key={i}
              label={h.label}
              value={h.value}
              delay={fps * 0.7 + i * 14}
              index={i}
            />
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
