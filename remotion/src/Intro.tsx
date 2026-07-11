import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, spring, useVideoConfig, Img, staticFile } from "remotion";
import { C, F } from "./theme";

/**
 * Scene 1 — The hook.
 * Slow cinematic zoom on the hero, headline fades up line by line.
 */
export const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // slow push-in on the whole scene
  const zoom = interpolate(frame, [0, 210], [1.06, 1.14], { extrapolateRight: "clamp" });

  const fadeUp = (delay: number) => {
    const s = spring({ frame: frame - delay, fps, config: { damping: 200, mass: 0.9 } });
    return {
      opacity: s,
      transform: `translateY(${interpolate(s, [0, 1], [26, 0])}px)`,
    };
  };

  const vignette = interpolate(frame, [0, 40], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: C.ivory, overflow: "hidden" }}>
      {/* hero image, slowly pushing in */}
      <AbsoluteFill style={{ transform: `scale(${zoom})`, transformOrigin: "50% 70%" }}>
        <Img
          src={staticFile("hero-figure.png")}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "center bottom",
          }}
        />
      </AbsoluteFill>

      {/* soft ivory wash so type reads cleanly */}
      <AbsoluteFill
        style={{
          opacity: vignette,
          background:
            "linear-gradient(180deg, rgba(244,241,233,.94) 0%, rgba(244,241,233,.55) 30%, rgba(244,241,233,0) 58%)",
        }}
      />

      <AbsoluteFill style={{ alignItems: "center", paddingTop: 120 }}>
        <div
          style={{
            ...fadeUp(6),
            fontFamily: F.sans,
            fontSize: 19,
            letterSpacing: "0.3em",
            textTransform: "uppercase",
            color: C.ink2,
          }}
        >
          Pre-signature verification for autonomous agents
        </div>

        <div
          style={{
            ...fadeUp(24),
            fontFamily: F.serif,
            fontSize: 104,
            lineHeight: 1.02,
            color: C.ink,
            textAlign: "center",
            marginTop: 34,
            letterSpacing: "-0.02em",
          }}
        >
          Look at the intent,
        </div>
        <div
          style={{
            ...fadeUp(42),
            fontFamily: F.serif,
            fontStyle: "italic",
            fontSize: 104,
            lineHeight: 1.02,
            color: C.ink,
            textAlign: "center",
            letterSpacing: "-0.02em",
          }}
        >
          not just the transaction.
        </div>

        <div
          style={{
            ...fadeUp(70),
            fontFamily: F.sans,
            fontSize: 25,
            lineHeight: 1.65,
            color: C.ink2,
            textAlign: "center",
            maxWidth: 760,
            marginTop: 34,
          }}
        >
          Every autonomous transaction is signed in the dark.
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
