import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig, Easing } from "remotion";

const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };

// A simple cinematic fade transition overlay.
// Render this at the seam between two scenes (first half: fade out, second half: fade in).
interface Props {
  type?: "fade" | "gold-flash" | "dark-dip";
}

export const TransitionOverlay: React.FC<Props> = ({ type = "fade" }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const mid = durationInFrames / 2;

  const opacity = interpolate(
    frame,
    [0, mid * 0.4, mid, mid + mid * 0.4, durationInFrames],
    [0, 1, 1, 1, 0],
    { ...clamp, easing: Easing.bezier(0.4, 0, 0.6, 1) }
  );

  const bg =
    type === "gold-flash"
      ? "rgba(201,162,39,0.9)"
      : type === "dark-dip"
      ? "#000"
      : "rgba(10,22,40,0.95)";

  return (
    <AbsoluteFill style={{ background: bg, opacity, pointerEvents: "none", zIndex: 100 }} />
  );
};
