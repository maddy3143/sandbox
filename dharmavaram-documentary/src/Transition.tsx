import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig, Easing } from "remotion";

const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };
const ez = Easing.bezier(0.4, 0, 0.6, 1);

export type TransitionType =
  | "dark-dip"
  | "fade"
  | "gold-flash"
  | "wipe-right"
  | "wipe-left"
  | "zoom-out"
  | "white-flash";

interface Props {
  type?: TransitionType;
}

export const TransitionOverlay: React.FC<Props> = ({ type = "fade" }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const mid = durationInFrames / 2;

  // ── dark-dip / fade ── fade to opaque color and back
  if (type === "dark-dip" || type === "fade") {
    const opacity = interpolate(
      frame,
      [0, mid * 0.35, mid, mid + mid * 0.35, durationInFrames],
      [0, 1, 1, 1, 0],
      { ...clamp, easing: ez }
    );
    const bg = type === "dark-dip" ? "#000000" : "rgba(10,22,40,0.97)";
    return <AbsoluteFill style={{ background: bg, opacity, pointerEvents: "none", zIndex: 100 }} />;
  }

  // ── gold-flash ── bright gold with fast on/off
  if (type === "gold-flash") {
    const opacity = interpolate(
      frame,
      [0, mid * 0.2, mid * 0.5, mid, mid + mid * 0.2, durationInFrames],
      [0, 1, 0.6, 0.8, 1, 0],
      clamp
    );
    return <AbsoluteFill style={{ background: "rgba(201,162,39,0.88)", opacity, pointerEvents: "none", zIndex: 100 }} />;
  }

  // ── white-flash ── cinematic flash
  if (type === "white-flash") {
    const opacity = interpolate(
      frame,
      [0, mid * 0.25, mid * 0.5, mid, mid + mid * 0.3, durationInFrames],
      [0, 1, 0.5, 0.9, 1, 0],
      clamp
    );
    return <AbsoluteFill style={{ background: "#ffffff", opacity, pointerEvents: "none", zIndex: 100 }} />;
  }

  // ── wipe-right ── panel sweeps left→center→right (black curtain)
  if (type === "wipe-right") {
    const tx = interpolate(
      frame,
      [0, mid * 0.45, mid, mid + mid * 0.45, durationInFrames],
      [-1940, 0, 0, 0, 1940],
      { ...clamp, easing: ez }
    );
    const opacity = interpolate(frame, [0, 8, durationInFrames - 8, durationInFrames], [0, 1, 1, 0], clamp);
    return (
      <AbsoluteFill style={{ overflow: "hidden", pointerEvents: "none", zIndex: 100 }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "#000",
            transform: `translateX(${tx}px)`,
            opacity,
          }}
        />
      </AbsoluteFill>
    );
  }

  // ── wipe-left ── panel sweeps right→center→left
  if (type === "wipe-left") {
    const tx = interpolate(
      frame,
      [0, mid * 0.45, mid, mid + mid * 0.45, durationInFrames],
      [1940, 0, 0, 0, -1940],
      { ...clamp, easing: ez }
    );
    const opacity = interpolate(frame, [0, 8, durationInFrames - 8, durationInFrames], [0, 1, 1, 0], clamp);
    return (
      <AbsoluteFill style={{ overflow: "hidden", pointerEvents: "none", zIndex: 100 }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "#060c18",
            transform: `translateX(${tx}px)`,
            opacity,
          }}
        />
      </AbsoluteFill>
    );
  }

  // ── zoom-out ── overlay scales up while fading in, suggests camera pull-back
  if (type === "zoom-out") {
    const opacity = interpolate(
      frame,
      [0, mid * 0.4, mid, mid + mid * 0.4, durationInFrames],
      [0, 1, 1, 1, 0],
      { ...clamp, easing: ez }
    );
    const scale = interpolate(frame, [0, mid], [0.92, 1.0], { ...clamp, easing: Easing.out(Easing.quad) });
    return (
      <AbsoluteFill style={{ pointerEvents: "none", zIndex: 100 }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "#000",
            opacity,
            transform: `scale(${scale})`,
            transformOrigin: "center center",
          }}
        />
      </AbsoluteFill>
    );
  }

  return null;
};
