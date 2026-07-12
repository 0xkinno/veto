import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, Series } from "remotion";
import { Intro } from "./Intro";
import { Handoff } from "./Handoff";
import { Verdict } from "./Verdict";
import { Dashboard } from "./Dashboard";
import { Outro } from "./Outro";
import { C } from "./theme";

/** Crossfade wrapper — fades a scene in and out at its edges. */
const Fade: React.FC<{ children: React.ReactNode; duration: number }> = ({ children, duration }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, 18, duration - 18, duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

// 30fps · total 60s = 1800 frames
const INTRO = 210;      // 7s
const HANDOFF = 240;    // 8s   — the hand-off between agents
const VERDICT = 660;    // 22s  — the product working (the wow)
const DASHBOARD = 420;  // 14s
const OUTRO = 270;      // 9s

export const VetoDemo: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: C.ivory }}>
      <Series>
        <Series.Sequence durationInFrames={INTRO}>
          <Fade duration={INTRO}>
            <Intro />
          </Fade>
        </Series.Sequence>

        <Series.Sequence durationInFrames={HANDOFF}>
          <Fade duration={HANDOFF}>
            <Handoff />
          </Fade>
        </Series.Sequence>

        <Series.Sequence durationInFrames={VERDICT}>
          <Fade duration={VERDICT}>
            <Verdict />
          </Fade>
        </Series.Sequence>

        <Series.Sequence durationInFrames={DASHBOARD}>
          <Fade duration={DASHBOARD}>
            <Dashboard />
          </Fade>
        </Series.Sequence>

        <Series.Sequence durationInFrames={OUTRO}>
          <Fade duration={OUTRO}>
            <Outro />
          </Fade>
        </Series.Sequence>
      </Series>
    </AbsoluteFill>
  );
};

export const TOTAL_FRAMES = INTRO + HANDOFF + VERDICT + DASHBOARD + OUTRO;
