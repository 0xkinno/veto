#!/usr/bin/env bash
# VETO — Remotion cinematic demo video
# Run from the root of your veto folder:  bash apply-remotion-video.sh
# Creates remotion/ — a React-to-MP4 product film. No recording, no clicking.
set -e
echo "Writing Remotion project into $(pwd)/remotion ..."
mkdir -p remotion/src remotion/public remotion/out

# ---------- remotion/package.json ----------
cat > remotion/package.json << 'VETO_FILE_1_END_9f3a'
{
  "name": "veto-remotion",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "render-video": "remotion render src/index.ts VetoDemo out/veto-demo.mp4 --codec=h264 --crf=17",
    "preview": "remotion studio src/index.ts"
  },
  "dependencies": {
    "@remotion/cli": "4.0.290",
    "remotion": "4.0.290",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.5",
    "typescript": "^5.6.2"
  }
}
VETO_FILE_1_END_9f3a

# ---------- remotion/tsconfig.json ----------
cat > remotion/tsconfig.json << 'VETO_FILE_2_END_9f3a'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["src"]
}
VETO_FILE_2_END_9f3a

# ---------- remotion/remotion.config.ts ----------
cat > remotion/remotion.config.ts << 'VETO_FILE_3_END_9f3a'
import { Config } from "@remotion/cli/config";

Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);
Config.setConcurrency(2);
VETO_FILE_3_END_9f3a

# ---------- remotion/.gitignore ----------
cat > remotion/.gitignore << 'VETO_FILE_4_END_9f3a'
node_modules/
out/
build/
VETO_FILE_4_END_9f3a

# ---------- remotion/README.md ----------
cat > remotion/README.md << 'VETO_FILE_5_END_9f3a'
# VETO — Cinematic Demo Video (Remotion)

Renders a 60-second 1080p product film **directly from React**. No browser to
open, no screen to record, no clicking. One command, one MP4.

## Setup (one time)

```bash
cd remotion
npm install
```

Remotion downloads what it needs automatically on install. ffmpeg is bundled.

## Render

```bash
npm run render-video
```

Output: **`out/veto-demo.mp4`** — 1920×1080, 30fps, ~56 seconds.

## Preview / tweak before rendering

```bash
npm run preview
```

Opens Remotion Studio: scrub the timeline, adjust timings live, then render.

## What it shows

| Scene | Duration | Content |
|---|---|---|
| **Intro** | 8s | Hero figure, slow cinematic push-in, headline fades up |
| **Verdict** | 22s | Animated cursor clicks the presets — **ALLOW**, then **VETO** with 3 findings, evidence hash, attestation |
| **Dashboard** | 16s | Live metrics counting up, screened-volume chart rising |
| **Outro** | 10s | "Agents propose. VETO disposes." |

Every scene uses the exact VETO palette, typography, and verdict colours from
the live site. Slow easing, fades, spring animation, no jump cuts.

## Voiceover script (60s)

**0:00–0:08** — "Autonomous agents sign transactions with no one watching. One poisoned transaction drains the wallet."

**0:08–0:18** — "VETO is the last check before an agent signs. An agent hands it a transaction and what it believes that transaction does."

**0:18–0:30** — "A clean swap. VETO forks X Layer, simulates the exact transaction, and finds no divergence. Effect matched intent. Cleared to sign."

**0:30–0:46** — "The same swap on the surface. But the simulation caught an unlimited approval to a known drainer the agent never declared. Intent and effect diverge. Signature refused — with an evidence hash, attested on X Layer."

**0:46–0:56** — "Every ruling, counted live, attested on-chain, paid per call in USDT. VETO. Agents propose. VETO disposes."

Add it in CapCut or ElevenLabs over the rendered MP4.

## Changing content

Edit the scene files directly — they are plain React:

- `src/Intro.tsx` — hero + headline
- `src/Verdict.tsx` — the console, cursor path, both rulings
- `src/Dashboard.tsx` — metrics and chart
- `src/Outro.tsx` — closing line
- `src/VetoDemo.tsx` — scene order and durations
VETO_FILE_5_END_9f3a

# ---------- remotion/src/index.ts ----------
cat > remotion/src/index.ts << 'VETO_FILE_6_END_9f3a'
import { registerRoot } from "remotion";
import { RemotionRoot } from "./Root";

registerRoot(RemotionRoot);
VETO_FILE_6_END_9f3a

# ---------- remotion/src/Root.tsx ----------
cat > remotion/src/Root.tsx << 'VETO_FILE_7_END_9f3a'
import React from "react";
import { Composition } from "remotion";
import { VetoDemo, TOTAL_FRAMES } from "./VetoDemo";
import "./fonts.css";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="VetoDemo"
      component={VetoDemo}
      durationInFrames={TOTAL_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
VETO_FILE_7_END_9f3a

# ---------- remotion/src/VetoDemo.tsx ----------
cat > remotion/src/VetoDemo.tsx << 'VETO_FILE_8_END_9f3a'
import React from "react";
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame, Series } from "remotion";
import { Intro } from "./Intro";
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
const INTRO = 240;      // 8s
const VERDICT = 660;    // 22s  — the product working (the wow)
const DASHBOARD = 480;  // 16s
const OUTRO = 300;      // 10s   (total 1680 = 56s, plus fades)

export const VetoDemo: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: C.ivory }}>
      <Series>
        <Series.Sequence durationInFrames={INTRO}>
          <Fade duration={INTRO}>
            <Intro />
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

export const TOTAL_FRAMES = INTRO + VERDICT + DASHBOARD + OUTRO;
VETO_FILE_8_END_9f3a

# ---------- remotion/src/Intro.tsx ----------
cat > remotion/src/Intro.tsx << 'VETO_FILE_9_END_9f3a'
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
VETO_FILE_9_END_9f3a

# ---------- remotion/src/Verdict.tsx ----------
cat > remotion/src/Verdict.tsx << 'VETO_FILE_10_END_9f3a'
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
VETO_FILE_10_END_9f3a

# ---------- remotion/src/Dashboard.tsx ----------
cat > remotion/src/Dashboard.tsx << 'VETO_FILE_11_END_9f3a'
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
VETO_FILE_11_END_9f3a

# ---------- remotion/src/Outro.tsx ----------
cat > remotion/src/Outro.tsx << 'VETO_FILE_12_END_9f3a'
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
VETO_FILE_12_END_9f3a

# ---------- remotion/src/Cursor.tsx ----------
cat > remotion/src/Cursor.tsx << 'VETO_FILE_13_END_9f3a'
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
VETO_FILE_13_END_9f3a

# ---------- remotion/src/theme.ts ----------
cat > remotion/src/theme.ts << 'VETO_FILE_14_END_9f3a'
/** VETO design tokens — identical to the live site. */
export const C = {
  ivory: "#F4F1E9",
  stone: "#ECE8DD",
  card: "#FFFFFF",
  ink: "#141311",
  ink2: "#5D584C",
  ink3: "#948E7E",
  emerald: "#2E7A57",
  emeraldBg: "rgba(46,122,87,.10)",
  amber: "#9A6E1E",
  amberBg: "rgba(154,110,30,.10)",
  crimson: "#96302E",
  crimsonBg: "rgba(150,48,46,.09)",
  slate: "#4E5F78",
  line: "rgba(20,19,17,.08)",
};

export const F = {
  sans: "'Inter Tight', -apple-system, Segoe UI, sans-serif",
  serif: "'Newsreader', Georgia, serif",
  mono: "'IBM Plex Mono', ui-monospace, monospace",
};

/** Cinematic easing — slow out, slow in. */
export const EASE = (t: number) =>
  t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
VETO_FILE_14_END_9f3a

# ---------- remotion/src/fonts.css ----------
cat > remotion/src/fonts.css << 'VETO_FILE_15_END_9f3a'
@import url("https://fonts.googleapis.com/css2?family=Inter+Tight:wght@400;500;600&family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;1,6..72,400&family=IBM+Plex+Mono:wght@400;500&display=swap");
VETO_FILE_15_END_9f3a

# copy the hero image into the remotion public folder
cp apps/web/public/hero-figure.png remotion/public/hero-figure.png
echo ""
echo "Done. To render your video:"
echo "  cd remotion"
echo "  npm install"
echo "  npm run render-video"
echo ""
echo "Output: remotion/out/veto-demo.mp4  (1920x1080, ~56s)"
echo "Preview/tweak first:  npm run preview"
