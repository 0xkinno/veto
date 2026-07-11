import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { EASE } from "./theme";

/** An animated cursor that glides between points with easing. */
export const Cursor: React.FC<{
  path: { f: number; x: number; y: number }[];
  clickAt?: number[];
}> = ({ path, clickAt = [] }) => {
  const frame = useCurrentFrame();

  const frames = path.map((p) => p.f);
  const xs = path.map((p) => p.x);
  const ys = path.map((p) => p.y);

  const x = interpolate(frame, frames, xs, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE,
  });
  const y = interpolate(frame, frames, ys, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE,
  });

  // click ripple
  const ripple = clickAt.reduce((acc, cf) => {
    const d = frame - cf;
    if (d >= 0 && d < 18) {
      const p = d / 18;
      return Math.max(acc, 1 - p);
    }
    return acc;
  }, 0);
  const rippleSize = interpolate(ripple, [0, 1], [46, 8]);

  return (
    <div style={{ position: "absolute", left: x, top: y, pointerEvents: "none", zIndex: 60 }}>
      {ripple > 0 && (
        <div
          style={{
            position: "absolute",
            left: -rippleSize / 2,
            top: -rippleSize / 2,
            width: rippleSize,
            height: rippleSize,
            borderRadius: "50%",
            border: "2px solid rgba(20,19,17,.45)",
            opacity: ripple,
          }}
        />
      )}
      {/* pointer */}
      <svg width="26" height="26" viewBox="0 0 24 24" style={{ filter: "drop-shadow(0 2px 6px rgba(0,0,0,.28))" }}>
        <path d="M5 2l14 8.5-6.2 1.6L9.6 19 5 2z" fill="#141311" stroke="#fff" strokeWidth="1.2" />
      </svg>
    </div>
  );
};
