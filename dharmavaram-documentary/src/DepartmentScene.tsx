import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import type { CSSProperties } from "react";
import { CAMERA_MOTIONS } from "./animations/cameraMotions";
import type { SceneConfig } from "./data/scenes";

interface Props {
  scene: SceneConfig;
}

// Portrait page (1530×1980) shown on a 1920×1080 landscape canvas.
// Back layer: same image blurred + scaled to fill canvas — no black bars.
// Front layer: page scaled to fill height (1080px), centered, camera-animated.

export const DepartmentScene: React.FC<Props> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const src = staticFile(`pages/page-${String(scene.page).padStart(2, "0")}.png`);
  const motionFn = CAMERA_MOTIONS[scene.animation];
  const motionStyle = motionFn(frame, fps, durationInFrames);

  // portrait ratio 1530/1980 ≈ 0.7727 → at 1080h the width ≈ 834px
  const portraitH = 1080;
  const portraitW = Math.round(portraitH * (1530 / 1980));

  const bgStyle: CSSProperties = {
    position: "absolute",
    inset: 0,
    backgroundImage: `url(${src})`,
    backgroundSize: "cover",
    backgroundPosition: "center",
    filter: "blur(28px) brightness(0.35) saturate(0.7)",
    transform: "scale(1.15)",
  };

  const frameStyle: CSSProperties = {
    position: "absolute",
    top: 0,
    left: "50%",
    width: portraitW,
    height: portraitH,
    marginLeft: -portraitW / 2,
    overflow: "hidden",
  };

  const imgStyle: CSSProperties = {
    width: "100%",
    height: "100%",
    objectFit: "cover",
    display: "block",
    transformOrigin: "center center",
    ...motionStyle,
  };

  return (
    <AbsoluteFill style={{ background: "#0A1628" }}>
      <div style={bgStyle} />
      <div style={frameStyle}>
        <Img src={src} style={imgStyle} />
      </div>
    </AbsoluteFill>
  );
};
