import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, F } from "./theme";
import { Cursor } from "./Cursor";

const Card: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({ children, style }) => (
  <div
    style={{
      background: C.card,
      border: `1px solid ${C.line}`,
      borderRadius: 20,
      boxShadow: "0 8px 40px rgba(30,40,30,.08)",
      padding: "34px 36px",
      ...style,
    }}
  >
    {children}
  </div>
);

const Row: React.FC<{ k: string; v: string; flag?: boolean }> = ({ k, v, flag }) => (
  <div
    style={{
      display: "flex",
      justifyContent: "space-between",
      alignItems: "baseline",
      padding: "13px 0",
      borderBottom: `1px solid ${C.line}`,
      fontFamily: F.sans,
      fontSize: 17,
      color: flag ? C.crimson : C.ink2,
    }}
  >
    <span>{k}</span>
    <span style={{ fontFamily: F.mono, fontSize: 15 }}>{v}</span>
  </div>
);

/**
 * Scene 2 — The verdict. The product working.
 * Cursor glides to the preset, clicks, the ruling lands: ALLOW, then VETO.
 */
export const Verdict: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const rise = (delay: number) => {
    const s = spring({ frame: frame - delay, fps, config: { damping: 200 } });
    return { opacity: s, transform: `translateY(${interpolate(s, [0, 1], [22, 0])}px)` };
  };

  // Timeline: ALLOW ruling ~ frame 70, VETO ruling ~ frame 190
  const allowIn = spring({ frame: frame - 72, fps, config: { damping: 200 } });
  const vetoIn = spring({ frame: frame - 196, fps, config: { damping: 190 } });
  const showVeto = frame >= 190;

  return (
    <AbsoluteFill style={{ background: C.stone, padding: "70px 90px", fontFamily: F.sans }}>
      <div style={{ ...rise(0), marginBottom: 34 }}>
        <div style={{ fontSize: 15, letterSpacing: ".28em", textTransform: "uppercase", color: C.ink2, display: "flex", alignItems: "center", gap: 14 }}>
          <span style={{ width: 30, height: 1, background: C.crimson, display: "inline-block" }} />
          Live verdict
        </div>
        <div style={{ fontFamily: F.serif, fontSize: 62, color: C.ink, marginTop: 16, letterSpacing: "-.01em" }}>
          Submit a transaction. Get a real ruling.
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 26 }}>
        {/* LEFT — the transaction */}
        <Card style={rise(10)}>
          <div style={{ fontSize: 20, fontWeight: 600, marginBottom: 4 }}>Transaction</div>
          <div style={{ fontSize: 15, color: C.ink3, marginBottom: 24 }}>
            An agent hands VETO the transaction and what it believes it does.
          </div>

          <div style={{ display: "flex", gap: 12, marginBottom: 22 }}>
            <div
              style={{
                fontSize: 15,
                padding: "10px 16px",
                borderRadius: 100,
                border: `1px solid ${showVeto ? C.line : C.ink}`,
                background: showVeto ? C.card : C.ink,
                color: showVeto ? C.ink2 : C.ivory,
              }}
            >
              Clean swap
            </div>
            <div
              style={{
                fontSize: 15,
                padding: "10px 16px",
                borderRadius: 100,
                border: `1px solid ${showVeto ? C.ink : C.line}`,
                background: showVeto ? C.ink : C.card,
                color: showVeto ? C.ivory : C.ink2,
              }}
            >
              Undeclared approval
            </div>
          </div>

          <Row k="Stated intent" v="Swap 50 USDT for OKB" />
          <Row k="From (agent)" v="0x1111…1111" />
          <Row k="To" v={showVeto ? "0x7f90…dc41" : "0x2222…2222"} />
          <Row k="Calldata" v={showVeto ? "0x095ea7b3" : "0x"} />
          <Row k="Policy" v={showVeto ? "treasury-strict" : "standard"} />

          <div
            style={{
              marginTop: 26,
              background: C.ink,
              color: C.ivory,
              borderRadius: 12,
              padding: "16px 0",
              textAlign: "center",
              fontSize: 18,
              fontWeight: 500,
            }}
          >
            Request verdict
          </div>
        </Card>

        {/* RIGHT — the ruling */}
        <Card style={rise(16)}>
          <div style={{ fontSize: 20, fontWeight: 600, marginBottom: 4 }}>Verdict</div>
          <div style={{ fontSize: 15, color: C.ink3, marginBottom: 24 }}>
            Simulated on X Layer. Evidence hashed. Attested on-chain.
          </div>

          {/* ALLOW */}
          {!showVeto && (
            <div style={{ opacity: allowIn, transform: `scale(${interpolate(allowIn, [0, 1], [0.96, 1])})` }}>
              <div style={{ display: "flex", alignItems: "center", gap: 22, background: C.emeraldBg, borderRadius: 16, padding: 26 }}>
                <div
                  style={{
                    width: 92, height: 92, borderRadius: "50%",
                    border: `2px solid ${C.emerald}`, color: C.emerald,
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontFamily: F.serif, fontSize: 17, letterSpacing: ".14em",
                  }}
                >
                  ALLOW
                </div>
                <div>
                  <div style={{ fontFamily: F.serif, fontStyle: "italic", fontSize: 30, color: C.emerald }}>
                    Cleared to sign.
                  </div>
                  <div style={{ fontSize: 16, color: C.ink2, marginTop: 6 }}>
                    Effect matched intent · no rule triggered
                  </div>
                </div>
              </div>
              <div style={{ marginTop: 26 }}>
                <Row k="Simulated at block" v="#65,025,303" />
                <Row k="Latency" v="1.23s" />
                <Row k="Evidence hash" v="0xfb41ae32…1462f0ae4" />
              </div>
            </div>
          )}

          {/* VETO */}
          {showVeto && (
            <div style={{ opacity: vetoIn, transform: `scale(${interpolate(vetoIn, [0, 1], [0.96, 1])})` }}>
              <div style={{ display: "flex", alignItems: "center", gap: 22, background: C.crimsonBg, borderRadius: 16, padding: 26 }}>
                <div
                  style={{
                    width: 92, height: 92, borderRadius: "50%",
                    border: `2px solid ${C.crimson}`, color: C.crimson,
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontFamily: F.serif, fontSize: 19, letterSpacing: ".14em",
                  }}
                >
                  VETO
                </div>
                <div>
                  <div style={{ fontFamily: F.serif, fontStyle: "italic", fontSize: 30, color: C.crimson }}>
                    Signature refused.
                  </div>
                  <div style={{ fontSize: 16, color: C.ink2, marginTop: 6 }}>3 findings</div>
                </div>
              </div>

              <div style={{ marginTop: 22, display: "flex", flexDirection: "column", gap: 11 }}>
                {[
                  "intent-divergence: Undeclared approval to 0x7f90…dc41 (unlimited)",
                  "approval-risk: Unlimited approval to a spender never declared",
                  "counterparty: Recipient is not on the registered ledger",
                ].map((r, i) => {
                  const fi = spring({ frame: frame - 210 - i * 12, fps, config: { damping: 200 } });
                  return (
                    <div key={i} style={{ opacity: fi, display: "flex", gap: 10, fontSize: 16, color: C.ink2, lineHeight: 1.5 }}>
                      <span style={{ color: C.crimson }}>•</span>
                      {r}
                    </div>
                  );
                })}
              </div>

              <div style={{ marginTop: 22 }}>
                <Row k="Simulated at block" v="#65,025,303" />
                <Row k="Evidence hash" v="0xb1d0115d…b471d57f5" flag={false} />
                <Row k="Attested on X Layer" v="0x0ddaea64…e9f0a231" />
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* the cursor: glides to the preset, clicks, then to the button, clicks */}
      <Cursor
        path={[
          { f: 0, x: 1560, y: 880 },
          { f: 34, x: 300, y: 470 },   // clean-swap preset
          { f: 46, x: 300, y: 470 },
          { f: 62, x: 470, y: 880 },   // request verdict
          { f: 150, x: 470, y: 880 },
          { f: 176, x: 470, y: 470 },  // undeclared-approval preset
          { f: 186, x: 470, y: 470 },
          { f: 200, x: 470, y: 880 },  // request verdict again
          { f: 300, x: 470, y: 880 },
        ]}
        clickAt={[44, 66, 184, 198]}
      />
    </AbsoluteFill>
  );
};
