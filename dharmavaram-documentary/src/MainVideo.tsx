import { AbsoluteFill, Sequence } from "remotion";
import { Intro } from "./Intro";
import { DepartmentScene } from "./DepartmentScene";
import { SummaryScene } from "./SummaryScene";
import { Ending } from "./Ending";
import { TransitionOverlay } from "./Transition";
import {
  DEPT_SCENES,
  FPS,
  TRANSITION_FRAMES,
  SUMMARY_DURATION_SEC,
  ENDING_DURATION_SEC,
} from "./data/scenes";

const INTRO_FRAMES   = 20 * FPS;  // 600
const TOC_FRAMES     =  5 * FPS;  // 150
const SUMMARY_FRAMES = SUMMARY_DURATION_SEC * FPS;  // 450
const ENDING_FRAMES  = ENDING_DURATION_SEC  * FPS;  // 600

// Transition types cycle through 4 styles
const TRANSITION_TYPES = ["dark-dip", "fade", "gold-flash", "fade"] as const;

export const MainVideo: React.FC = () => {
  // Build cumulative start times
  let cursor = 0;

  // Intro
  const introStart = cursor;
  cursor += INTRO_FRAMES;

  // TOC (page-02)
  const tocStart = cursor;
  cursor += TOC_FRAMES;

  // Department scenes
  const deptStarts: number[] = [];
  for (let i = 0; i < DEPT_SCENES.length; i++) {
    const sceneFrames = DEPT_SCENES[i].durationSec * FPS;
    deptStarts.push(cursor);
    if (i < DEPT_SCENES.length - 1) {
      cursor += sceneFrames - TRANSITION_FRAMES;
    } else {
      cursor += sceneFrames;
    }
  }

  // Summary
  const summaryStart = cursor;
  cursor += SUMMARY_FRAMES;

  // Ending
  const endingStart = cursor;

  return (
    <AbsoluteFill style={{ background: "#0A1628" }}>

      {/* ── Intro ── */}
      <Sequence from={introStart} durationInFrames={INTRO_FRAMES}>
        <Intro />
      </Sequence>

      {/* ── TOC page ── */}
      <Sequence from={tocStart} durationInFrames={TOC_FRAMES}>
        <DepartmentScene scene={{ page: 2, dept: "విషయ సూచిక", animation: "fadeZoomClassic", durationSec: 5 }} />
      </Sequence>

      {/* ── Department scenes ── */}
      {DEPT_SCENES.map((scene, i) => {
        const from  = deptStarts[i];
        const dur   = scene.durationSec * FPS;
        const tType = TRANSITION_TYPES[i % TRANSITION_TYPES.length];
        return (
          <Sequence key={scene.page} from={from} durationInFrames={dur}>
            <AbsoluteFill>
              <DepartmentScene scene={scene} />
              {/* Transition overlay at end of scene (except last dept) */}
              {i < DEPT_SCENES.length - 1 && (
                <Sequence from={dur - TRANSITION_FRAMES} durationInFrames={TRANSITION_FRAMES}>
                  <TransitionOverlay type={tType} />
                </Sequence>
              )}
            </AbsoluteFill>
          </Sequence>
        );
      })}

      {/* ── Summary ── */}
      <Sequence from={summaryStart} durationInFrames={SUMMARY_FRAMES}>
        <SummaryScene />
      </Sequence>

      {/* ── Ending ── */}
      <Sequence from={endingStart} durationInFrames={ENDING_FRAMES}>
        <Ending />
      </Sequence>

    </AbsoluteFill>
  );
};

// Export total frame count for Root.tsx
export function totalFrames(): number {
  let t = INTRO_FRAMES + TOC_FRAMES;
  for (const s of DEPT_SCENES) t += s.durationSec * FPS - TRANSITION_FRAMES;
  t += DEPT_SCENES[DEPT_SCENES.length - 1].durationSec * FPS - (DEPT_SCENES[DEPT_SCENES.length - 1].durationSec * FPS - TRANSITION_FRAMES);
  // correct: last scene not cut short
  t = INTRO_FRAMES + TOC_FRAMES;
  for (let i = 0; i < DEPT_SCENES.length; i++) {
    const sf = DEPT_SCENES[i].durationSec * FPS;
    t += i < DEPT_SCENES.length - 1 ? sf - TRANSITION_FRAMES : sf;
  }
  t += SUMMARY_FRAMES + ENDING_FRAMES;
  return t;
}
