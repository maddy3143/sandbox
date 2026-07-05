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

const PhotoTile: React.FC<{
  src: string;
  delay: number;
  style?: CSSProperties;
  direction?: "left" | "bottom" | "top";
}> = ({ src, delay, style, direction = "left" }) => {
  const frame = useCurrentFrame();
  const op = interpolate(frame, [delay, delay + 20], [0, 1], clamp);
  const tx =
    direction === "left"
      ? interpolate(frame, [delay, delay + 30], [-60, 0], { ...clamp, easing: ez })
      : 0;
  const ty =
    direction === "bottom"
      ? interpolate(frame, [delay, delay + 30], [60, 0], { ...clamp, easing: ez })
      : direction === "top"
      ? interpolate(frame, [delay, delay + 30], [-60, 0], { ...clamp, easing: ez })
      : 0;
  const scale = interpolate(frame, [0, 450], [1.05, 1.0], clamp);

  return (
    <div
      style={{
        ...style,
        opacity: op,
        transform: `translate(${tx}px, ${ty}px)`,
        overflow: "hidden",
        borderRadius: 10,
        boxShadow: "0 8px 40px rgba(0,0,0,0.6)",
        border: "1.5px solid rgba(201,162,39,0.25)",
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          transform: `scale(${scale})`,
          transformOrigin: "center center",
        }}
      />
    </div>
  );
};

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

export const DepartmentScene: React.FC<{ scene: SceneConfig }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const content = DEPT_CONTENT[scene.page];
  const images = content?.images ?? [];
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
          background: "linear-gradient(135deg, rgba(10,22,40,0.7) 0%, rgba(10,22,40,0.35) 100%)",
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
          {images.length === 1 && (
            <PhotoTile src={images[0]} delay={8} direction="left" style={{ height: 580, width: "100%" }} />
          )}
          {images.length === 2 && (
            <>
              <PhotoTile src={images[0]} delay={8} direction="left" style={{ flex: 1 }} />
              <PhotoTile src={images[1]} delay={20} direction="bottom" style={{ flex: 1 }} />
            </>
          )}
          {images.length >= 3 && (
            <>
              <PhotoTile src={images[0]} delay={8} direction="left" style={{ height: 270, width: "100%" }} />
              <div style={{ display: "flex", gap: 12, flex: 1 }}>
                <PhotoTile src={images[1]} delay={20} direction="bottom" style={{ flex: 1, height: 260 }} />
                <PhotoTile src={images[2]} delay={32} direction="top" style={{ flex: 1, height: 260 }} />
                {images[3] && (
                  <PhotoTile src={images[3]} delay={44} direction="bottom" style={{ flex: 1, height: 260 }} />
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
