import { Easing, interpolate } from "remotion";
import type { CSSProperties } from "react";
import type { AnimationKey } from "../data/scenes";

type MotionFn = (frame: number, fps: number, total: number) => CSSProperties;

const ez = (a: number, b: number, c: number, d: number) =>
  Easing.bezier(a, b, c, d);

const clamp = { extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const };

// ─── 26 unique camera motion functions ───────────────────────────────────────

const slowCinematicZoom: MotionFn = (f, _fps, total) => ({
  scale: String(interpolate(f, [0, total], [1.0, 1.12], clamp)),
});

const parallaxScrollDown: MotionFn = (f, _fps, total) => ({
  translate: `0px ${interpolate(f, [0, total], [0, -60], clamp)}px`,
  scale: String(interpolate(f, [0, total], [1.05, 1.0], clamp)),
});

const cameraOrbit: MotionFn = (f, _fps, total) => ({
  rotate: `${interpolate(f, [0, total], [-0.8, 0.8], clamp)}deg`,
  scale: String(interpolate(f, [0, total / 2, total], [1.0, 1.06, 1.0], clamp)),
});

const depthPush: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    scale: String(interpolate(f, [0, enter, total], [0.88, 1.0, 1.05], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    opacity: interpolate(f, [0, enter * 0.6], [0, 1], clamp),
  };
};

const maskRevealTop: MotionFn = (f, fps, total) => {
  const enter = fps * 1.2;
  const ty = interpolate(f, [0, enter], [-80, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) });
  return {
    translate: `0px ${ty}px`,
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
    scale: String(interpolate(f, [enter, total], [1.0, 1.06], clamp)),
  };
};

const splitScreenSlide: MotionFn = (f, fps, _total) => {
  const enter = fps * 1.0;
  return {
    translate: `${interpolate(f, [0, enter], [-120, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })}px 0px`,
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
  };
};

const floatingCard: MotionFn = (f, fps, _total) => ({
  translate: `0px ${Math.sin((f / fps) * Math.PI * 0.4) * 8}px`,
  scale: String(1.0 + Math.sin((f / fps) * Math.PI * 0.3) * 0.006),
});

const kenBurnsDiagonal: MotionFn = (f, _fps, total) => ({
  scale: String(interpolate(f, [0, total], [1.0, 1.14], clamp)),
  translate: `${interpolate(f, [0, total], [0, -40], clamp)}px ${interpolate(f, [0, total], [0, -25], clamp)}px`,
});

const dynamicGridReveal: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    scale: String(interpolate(f, [0, enter, total], [0.9, 1.0, 1.05], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    opacity: interpolate(f, [0, enter], [0, 1], clamp),
  };
};

const glassMorphismSlide: MotionFn = (f, fps, total) => {
  const enter = fps * 1.0;
  return {
    translate: `${interpolate(f, [0, enter], [100, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })}px 0px`,
    scale: String(interpolate(f, [enter, total], [1.0, 1.06], clamp)),
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
  };
};

const cameraPush3D: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    perspective: "800px",
    scale: String(interpolate(f, [0, enter, total], [0.7, 1.0, 1.08], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
  };
};

const perspectiveRotateY: MotionFn = (f, fps, _total) => {
  const enter = fps * 1.2;
  const rot = interpolate(f, [0, enter], [-12, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) });
  return {
    rotateY: `${rot}deg`,
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
    scale: String(interpolate(f, [0, enter], [0.92, 1.0], clamp)),
  };
};

const imageMosaicAssemble: MotionFn = (f, fps, total) => {
  const enter = fps * 2;
  return {
    scale: String(interpolate(f, [0, enter, total], [1.15, 1.0, 1.06], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    opacity: interpolate(f, [0, enter * 0.4], [0, 1], clamp),
  };
};

const diagonalReveal: MotionFn = (f, fps, total) => {
  const enter = fps * 1.2;
  return {
    translate: `${interpolate(f, [0, enter], [80, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })}px ${interpolate(f, [0, enter], [-50, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })}px`,
    opacity: interpolate(f, [0, enter * 0.6], [0, 1], clamp),
    scale: String(interpolate(f, [enter, total], [1.0, 1.08], clamp)),
  };
};

const ribbonUnroll: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    scaleY: String(interpolate(f, [0, enter], [0, 1], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    scale: String(interpolate(f, [enter, total], [1.0, 1.06], clamp)),
    opacity: interpolate(f, [0, enter * 0.3], [0, 1], clamp),
  };
};

const particleReveal: MotionFn = (f, fps, total) => {
  const enter = fps * 2;
  return {
    opacity: interpolate(f, [0, enter], [0, 1], { ...clamp, easing: ez(0.16, 1, 0.3, 1) }),
    scale: String(interpolate(f, [0, enter, total], [1.1, 1.0, 1.06], clamp)),
    filter: `blur(${interpolate(f, [0, enter], [12, 0], clamp)}px)`,
  };
};

const imageStackFan: MotionFn = (f, fps, total) => {
  const enter = fps * 1.0;
  return {
    rotate: `${interpolate(f, [0, enter], [6, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })}deg`,
    scale: String(interpolate(f, [0, enter, total], [0.88, 1.0, 1.05], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
  };
};

const timelineScroll: MotionFn = (f, _fps, total) => ({
  translate: `${interpolate(f, [0, total], [30, -30], clamp)}px 0px`,
  scale: String(interpolate(f, [0, total], [1.02, 1.08], clamp)),
});

const circularReveal: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    scale: String(interpolate(f, [0, enter, total], [0.5, 1.0, 1.06], { ...clamp, easing: ez(0.34, 1.56, 0.64, 1) })),
    opacity: interpolate(f, [0, enter * 0.4], [0, 1], clamp),
    rotate: `${interpolate(f, [0, enter], [-5, 0], clamp)}deg`,
  };
};

const magazineFlip: MotionFn = (f, fps, _total) => {
  const enter = fps * 1.2;
  const rot = interpolate(f, [0, enter], [90, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) });
  return {
    rotateY: `${rot}deg`,
    opacity: interpolate(f, [0, enter * 0.3], [0, 1], clamp),
    scale: String(interpolate(f, [0, enter], [0.85, 1.0], clamp)),
  };
};

const curtainOpen: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    scale: String(interpolate(f, [0, enter, total], [0.94, 1.0, 1.06], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    opacity: interpolate(f, [0, enter * 0.4], [0, 1], clamp),
  };
};

const pageTurnFlip: MotionFn = (f, fps, total) => {
  const enter = fps * 1.0;
  return {
    rotateX: `${interpolate(f, [0, enter], [20, 0], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })}deg`,
    opacity: interpolate(f, [0, enter * 0.5], [0, 1], clamp),
    scale: String(interpolate(f, [enter, total], [1.0, 1.06], clamp)),
  };
};

const shutterReveal: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    scaleX: String(interpolate(f, [0, enter], [0, 1], { ...clamp, easing: ez(0.16, 1, 0.3, 1) })),
    scale: String(interpolate(f, [enter, total], [1.0, 1.05], clamp)),
    opacity: interpolate(f, [0, enter * 0.3], [0, 1], clamp),
  };
};

const bounceIn: MotionFn = (f, fps, _total) => {
  const enter = fps * 1.2;
  const s = interpolate(f, [0, enter], [0, 1], { ...clamp, easing: ez(0.34, 1.56, 0.64, 1) });
  return {
    scale: String(s),
    opacity: interpolate(f, [0, enter * 0.3], [0, 1], clamp),
  };
};

const lightStreakSettle: MotionFn = (f, fps, total) => {
  const enter = fps * 1.0;
  return {
    filter: `brightness(${interpolate(f, [0, enter * 0.3, enter], [2.5, 1.5, 1.0], clamp)})`,
    scale: String(interpolate(f, [0, enter, total], [1.08, 1.0, 1.06], clamp)),
    opacity: interpolate(f, [0, enter * 0.2], [0, 1], clamp),
  };
};

const fadeZoomClassic: MotionFn = (f, fps, total) => {
  const enter = fps * 1.5;
  return {
    opacity: interpolate(f, [0, enter], [0, 1], { ...clamp, easing: ez(0.16, 1, 0.3, 1) }),
    scale: String(interpolate(f, [0, total], [1.04, 1.12], clamp)),
  };
};

export const CAMERA_MOTIONS: Record<AnimationKey, MotionFn> = {
  slowCinematicZoom,
  parallaxScrollDown,
  cameraOrbit,
  depthPush,
  maskRevealTop,
  splitScreenSlide,
  floatingCard,
  kenBurnsDiagonal,
  dynamicGridReveal,
  glassMorphismSlide,
  cameraPush3D,
  perspectiveRotateY,
  imageMosaicAssemble,
  diagonalReveal,
  ribbonUnroll,
  particleReveal,
  imageStackFan,
  timelineScroll,
  circularReveal,
  magazineFlip,
  curtainOpen,
  pageTurnFlip,
  shutterReveal,
  bounceIn,
  lightStreakSettle,
  fadeZoomClassic,
};
