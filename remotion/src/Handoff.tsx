import React from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { C, F } from "./theme";

/**
 * Scene — The hand-off.
 * Two agents passing value between them. VETO stands in the gap.
 */
export const Handoff: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // slow push-in on the sky
  const zoom = interpolate(frame, [0, 200], [1.04, 1.12], { extrapolateRight: "clamp" });

  const tokens = [
    { sym: "OKB", name: "OKB", sub: "X Layer", val: "$52.14", chip: "verified", color: "#2E3A4E", chipColor: C.emerald, chipBg: C.emeraldBg },
    { sym: "BTC", name: "Bitcoin", sub: "BTC", val: "$4,235.17", chip: "verified", color: "#8A6B2E", chipColor: C.emerald, chipBg: C.emeraldBg },
    { sym: "ETH", name: "Ethereum", sub: "ETH", val: "$1,250.08", chip: "warn", color: "#4E5F78", chipColor: C.amber, chipBg: C.amberBg },
    { sym: "SOL", name: "Solana", sub: "SOL", val: "$212.40", chip: "refused", color: "#3E7A64", chipColor: C.crimson, chipBg: C.crimsonBg },
  ];

  const caption = spring({ frame: frame - 120, fps, config: { damping: 200 } });

  return (
    <AbsoluteFill style={{ background: C.ivory, overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `scale(${zoom})` }}>
        <Img
          src={staticFile("hands-sky.png")}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            WebkitMaskImage:
              "linear-gradient(180deg,transparent 0%,#000 12%,#000 88%,transparent 100%)",
            maskImage:
              "linear-gradient(180deg,transparent 0%,#000 12%,#000 88%,transparent 100%)",
          }}
        />
      </AbsoluteFill>

      {/* token stack floating in the gap between the hands */}
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 14, width: 560 }}>
          {tokens.map((t, i) => {
            const s = spring({ frame: frame - 16 - i * 10, fps, config: { damping: 200 } });
            return (
              <div
                key={t.sym}
                style={{
                  opacity: s,
                  transform: `translateY(${interpolate(s, [0, 1], [26, 0])}px)`,
                  display: "flex",
                  alignItems: "center",
                  gap: 16,
                  background: C.card,
                  border: `1px solid ${C.line}`,
                  borderRadius: 14,
                  padding: "16px 20px",
                  boxShadow: "0 8px 30px rgba(30,40,30,.10)",
                  fontFamily: F.sans,
                }}
              >
                <span
                  style={{
                    width: 42, height: 42, borderRadius: "50%",
                    background: t.color, color: "#fff",
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontSize: 12, fontWeight: 600, letterSpacing: ".04em",
                  }}
                >
                  {t.sym}
                </span>
                <div style={{ display: "flex", flexDirection: "column" }}>
                  <b style={{ fontSize: 17, color: C.ink }}>{t.name}</b>
                  <span style={{ fontSize: 13, color: C.ink3 }}>{t.sub}</span>
                </div>
                <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 12 }}>
                  <b style={{ fontSize: 17, color: C.ink }}>{t.val}</b>
                  <span
                    style={{
                      fontSize: 11,
                      padding: "5px 10px",
                      borderRadius: 100,
                      background: t.chipBg,
                      color: t.chipColor,
                      fontWeight: 600,
                      letterSpacing: ".04em",
                    }}
                  >
                    {t.chip}
                  </span>
                </div>
              </div>
            );
          })}
        </div>

        <div
          style={{
            opacity: caption,
            transform: `translateY(${interpolate(caption, [0, 1], [18, 0])}px)`,
            fontFamily: F.serif,
            fontSize: 34,
            color: C.ink,
            marginTop: 54,
            textAlign: "center",
          }}
        >
          Every hand-off between agents, verified in the middle.
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
