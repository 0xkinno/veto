import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, F } from "./theme";

const Metric: React.FC<{ k: string; v: string; sub: string; color?: string; delay: number }> = ({ k, v, sub, color, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - delay, fps, config: { damping: 200 } });
  // count-up
  const target = parseFloat(v.replace(/[^0-9.]/g, "")) || 0;
  const shown = Math.round(interpolate(s, [0, 1], [0, target]));
  return (
    <div
      style={{
        opacity: s,
        transform: `translateY(${interpolate(s, [0, 1], [22, 0])}px)`,
        background: C.card,
        border: `1px solid ${C.line}`,
        borderRadius: 18,
        padding: "26px 28px",
      }}
    >
      <div style={{ fontSize: 16, color: C.ink3 }}>{k}</div>
      <div style={{ fontSize: 54, fontWeight: 600, color: color ?? C.ink, marginTop: 10, letterSpacing: "-.02em" }}>
        {v.includes("USDT") ? `${shown}` : shown.toLocaleString()}
        {v.includes("USDT") && <span style={{ fontSize: 22, color: C.ink3 }}> USDT</span>}
      </div>
      <div style={{ fontSize: 15, color: C.ink3, marginTop: 8 }}>{sub}</div>
    </div>
  );
};

/** Scene 3 — The ledger. Every ruling counted, attested, paid. */
export const Dashboard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const head = spring({ frame, fps, config: { damping: 200 } });

  // rising bars
  const bars = [38, 56, 44, 72, 92, 60, 50];

  return (
    <AbsoluteFill style={{ background: C.stone, padding: "70px 90px", fontFamily: F.sans }}>
      <div style={{ opacity: head, transform: `translateY(${interpolate(head, [0, 1], [20, 0])}px)` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 14 }}>
          <span style={{ width: 9, height: 9, borderRadius: "50%", background: C.emerald, display: "inline-block" }} />
          <span style={{ fontSize: 16, color: C.ink2 }}>Engine live · real-time</span>
        </div>
        <div style={{ fontFamily: F.serif, fontSize: 58, color: C.ink, letterSpacing: "-.01em" }}>Verdict Overview</div>
        <div style={{ fontSize: 19, color: C.ink2, marginTop: 10 }}>
          Every ruling this engine has issued — simulated, diffed, and attested on X Layer.
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 20, marginTop: 40 }}>
        <Metric k="Total Verdicts" v="1284" sub="rulings issued" delay={14} />
        <Metric k="Allowed" v="1243" sub="effect matched intent" delay={22} />
        <Metric k="Vetoed" v="41" sub="$182,400 exposure refused" color={C.crimson} delay={30} />
        <Metric k="x402 Revenue" v="318 USDT" sub="0.15–0.50 per ruling" delay={38} />
      </div>

      {/* chart */}
      <div
        style={{
          marginTop: 26,
          background: C.card,
          border: `1px solid ${C.line}`,
          borderRadius: 18,
          padding: "28px 32px",
          flex: 1,
        }}
      >
        <div style={{ fontSize: 20, fontWeight: 600 }}>Screened volume</div>
        <div style={{ fontSize: 15, color: C.ink3, marginBottom: 26 }}>Every transaction, judged before it was signed</div>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 22, height: 210 }}>
          {bars.map((h, i) => {
            const s = spring({ frame: frame - 46 - i * 6, fps, config: { damping: 200 } });
            return (
              <div
                key={i}
                style={{
                  flex: 1,
                  height: `${h * s}%`,
                  background: i === 4 ? C.crimson : C.slate,
                  opacity: i === 4 ? 0.95 : 0.5,
                  borderRadius: "8px 8px 3px 3px",
                }}
              />
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};
