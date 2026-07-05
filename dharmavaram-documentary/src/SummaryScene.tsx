import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig, Easing } from "remotion";

const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };

export const SummaryScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = fps * 1.2;
  const imgOpacity = interpolate(frame, [0, enter], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const imgScale = interpolate(frame, [0, fps * 15], [1.0, 1.08], clamp);

  const src = staticFile("pages/page-29.png");

  return (
    <AbsoluteFill style={{ background: "#0A1628" }}>
      <div style={{
        position: "absolute",
        inset: 0,
        backgroundImage: `url(${src})`,
        backgroundSize: "cover",
        backgroundPosition: "center",
        filter: "blur(28px) brightness(0.35)",
        transform: "scale(1.15)",
      }} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", opacity: imgOpacity }}>
        <div style={{ width: Math.round(1080 * (1530 / 1980)), height: 1080, overflow: "hidden" }}>
          <Img
            src={src}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              scale: String(imgScale),
              transformOrigin: "center center",
            }}
          />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
