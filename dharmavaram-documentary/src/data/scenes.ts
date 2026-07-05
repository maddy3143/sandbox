export type AnimationKey =
  | "slowCinematicZoom"
  | "parallaxScrollDown"
  | "cameraOrbit"
  | "depthPush"
  | "maskRevealTop"
  | "splitScreenSlide"
  | "floatingCard"
  | "kenBurnsDiagonal"
  | "dynamicGridReveal"
  | "glassMorphismSlide"
  | "cameraPush3D"
  | "perspectiveRotateY"
  | "imageMosaicAssemble"
  | "diagonalReveal"
  | "ribbonUnroll"
  | "particleReveal"
  | "imageStackFan"
  | "timelineScroll"
  | "circularReveal"
  | "magazineFlip"
  | "curtainOpen"
  | "pageTurnFlip"
  | "shutterReveal"
  | "bounceIn"
  | "lightStreakSettle"
  | "fadeZoomClassic";

export interface SceneConfig {
  page: number;
  dept: string;
  animation: AnimationKey;
  durationSec: number;
}

export const DEPT_SCENES: SceneConfig[] = [
  { page: 3,  dept: "ప్రధాన అభివృద్ధి ప్రాజెక్టులు",   animation: "slowCinematicZoom",   durationSec: 15 },
  { page: 4,  dept: "రహదారులు మరియు అభివృద్ధి",         animation: "parallaxScrollDown",  durationSec: 15 },
  { page: 5,  dept: "PR&RD పంచాయతీ రాజ్",              animation: "cameraOrbit",         durationSec: 15 },
  { page: 6,  dept: "PR&RD ఇంజనీరింగ్",                animation: "depthPush",           durationSec: 15 },
  { page: 7,  dept: "RWS&S నీటి సరఫరా",                animation: "maskRevealTop",       durationSec: 15 },
  { page: 8,  dept: "వ్యవసాయం",                         animation: "splitScreenSlide",    durationSec: 15 },
  { page: 9,  dept: "హ్యాండ్లూమ్ వస్త్రాలు",            animation: "floatingCard",        durationSec: 15 },
  { page: 10, dept: "అటవీ శాఖ",                        animation: "kenBurnsDiagonal",    durationSec: 15 },
  { page: 11, dept: "పౌర సరఫరాలు",                     animation: "dynamicGridReveal",   durationSec: 15 },
  { page: 12, dept: "భూగర్భ జలాలు",                    animation: "glassMorphismSlide",  durationSec: 15 },
  { page: 13, dept: "DRDA",                             animation: "cameraPush3D",        durationSec: 15 },
  { page: 14, dept: "MEPMA మహిళా సాధికారత",            animation: "perspectiveRotateY",  durationSec: 15 },
  { page: 15, dept: "నీటిపారుదల",                      animation: "imageMosaicAssemble", durationSec: 15 },
  { page: 16, dept: "ధర్మవరం మునిసిపాలిటీ",            animation: "diagonalReveal",      durationSec: 15 },
  { page: 17, dept: "వైద్య మరియు ఆరోగ్య",              animation: "ribbonUnroll",        durationSec: 15 },
  { page: 18, dept: "CMRF & ఆయుష్మాన్ భారత్",         animation: "particleReveal",      durationSec: 15 },
  { page: 19, dept: "విద్య — PM SHRI",                 animation: "imageStackFan",       durationSec: 15 },
  { page: 20, dept: "SC/ST/BC సంక్షేమం",               animation: "timelineScroll",      durationSec: 15 },
  { page: 21, dept: "విద్యుత్తు APSPDCL",              animation: "circularReveal",      durationSec: 15 },
  { page: 22, dept: "రోడ్లు మరియు భవనాలు",             animation: "magazineFlip",        durationSec: 15 },
  { page: 23, dept: "మహిళా శిశు సంక్షేమం",             animation: "curtainOpen",         durationSec: 15 },
  { page: 24, dept: "పరిశ్రమలు & MSME",               animation: "pageTurnFlip",        durationSec: 15 },
  { page: 25, dept: "గృహనిర్మాణం",                     animation: "shutterReveal",       durationSec: 15 },
  { page: 26, dept: "రవాణా APSRTC",                    animation: "bounceIn",            durationSec: 15 },
  { page: 27, dept: "సన్నుత్తి సేవా సమితి",             animation: "lightStreakSettle",   durationSec: 15 },
  { page: 28, dept: "సన్నుత్తి ఆరోగ్య సేవ",            animation: "fadeZoomClassic",     durationSec: 15 },
];

export const FPS = 30;
export const TRANSITION_FRAMES = 30; // 1 second overlap between scenes

// Pre-computed cumulative start frames for each dept scene (accounting for transitions)
export function getSceneStartFrame(index: number): number {
  const INTRO_FRAMES = 20 * FPS;    // 600
  const TOC_FRAMES   =  5 * FPS;    // 150
  let start = INTRO_FRAMES + TOC_FRAMES;
  for (let i = 0; i < index; i++) {
    start += DEPT_SCENES[i].durationSec * FPS - TRANSITION_FRAMES;
  }
  return start;
}

export const SUMMARY_PAGE = 29;
export const ENDING_PAGE  = 30;
export const SUMMARY_DURATION_SEC = 15;
export const ENDING_DURATION_SEC  = 20;
