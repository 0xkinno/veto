import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, F } from "./theme";

/** Scene 4 — The line. */
export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: frame - 6, fps, config: { damping: 200 } });
  const b = spring({ frame: frame - 26, fps, config: { damping: 200 } });
  const c = spring({ frame: frame - 54, fps, config: { damping: 200 } });

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(1200px 700px at 50% 60%, #FBF8F1, ${C.ivory})`,
        alignItems: "center",
        justifyContent: "center",
        fontFamily: F.sans,
      }}
    >
      <div
        style={{
          opacity: a,
          fontSize: 16,
          letterSpacing: ".32em",
          textTransform: "uppercase",
          color: C.ink2,
          marginBottom: 34,
        }}
      >
        The standard
      </div>
      <div
        style={{
          opacity: b,
          transform: `translateY(${interpolate(b, [0, 1], [24, 0])}px)`,
          fontFamily: F.serif,
          fontSize: 108,
          lineHeight: 1.06,
          color: C.ink,
          textAlign: "center",
          letterSpacing: "-.02em",
        }}
      >
        Agents propose.
        <br />
        VETO disposes.
      </div>
      <div
        style={{
          opacity: c,
          fontSize: 22,
          color: C.ink2,
          marginTop: 38,
          textAlign: "center",
        }}
      >
        Live on X Layer · Listed on OKX.AI · Paid per ruling
      </div>
    </AbsoluteFill>
  );
};
