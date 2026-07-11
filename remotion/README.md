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
