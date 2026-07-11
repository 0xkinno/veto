#!/usr/bin/env bash
# VETO — hands image fix + Remotion video (with the hands scene)
# Run from the root of your veto folder:  bash apply-hands-fix.sh
#
# 1. Adds the missing <img class="hands-img"> to the landing (exactly as the approved HTML)
# 2. Adds the Handoff scene to the Remotion video so the hands appear there too
#
# NOTE: you must place hands-sky.png into apps/web/public/ yourself (see below).
set -e
echo "Applying hands fix into $(pwd) ..."
mkdir -p apps/web/public apps/web/app remotion/src remotion/public

# ---------- apps/web/app/page.tsx ----------
cat > apps/web/app/page.tsx << 'VETO_FILE_1_END_9f3a'
"use client";

import { useEffect, useRef } from "react";
import Lenis from "lenis";
import "../styles/landing.css";

export default function Home() {
  const trackRef = useRef<HTMLDivElement>(null);
  const barRef = useRef<HTMLElement>(null);
  const hslidesRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const reduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    const isTouch = window.matchMedia("(max-width: 640px)").matches;

    // Lenis smooth scroll (skipped when reduced motion is requested).
    let lenis: Lenis | null = null;
    if (!reduced) {
      lenis = new Lenis({ duration: 1.1, smoothWheel: true });
      const raf = (time: number) => {
        lenis?.raf(time);
        requestAnimationFrame(raf);
      };
      requestAnimationFrame(raf);
    }

    // Reveal-on-scroll.
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.15 }
    );
    document.querySelectorAll(".rv").forEach((el) => io.observe(el));

    // Hero parallax — panels drift with scroll + mouse.
    const cards = [...document.querySelectorAll<HTMLElement>(".panelcard")];
    let mx = 0;
    let my = 0;
    const onMove = (e: MouseEvent) => {
      mx = e.clientX / window.innerWidth - 0.5;
      my = e.clientY / window.innerHeight - 0.5;
    };
    if (!isTouch && !reduced) window.addEventListener("mousemove", onMove, { passive: true });

    // Horizontal slides — scroll-driven deck (desktop only).
    let target = 0;
    let current = 0;
    let rafId = 0;

    const tick = () => {
      if (!isTouch && !reduced) {
        const sc = Math.min(window.scrollY, 700);
        cards.forEach((c) => {
          const d = Number(c.dataset.depth);
          const base = c.classList.contains("pc2") ? "translateX(-50%) " : "";
          c.style.transform = `${base}translate3d(${mx * d}px, ${
            my * d - (sc * d) / 34
          }px, 0)`;
        });

        const hs = hslidesRef.current;
        const track = trackRef.current;
        const bar = barRef.current;
        if (hs && track) {
          const r = hs.getBoundingClientRect();
          const total = hs.offsetHeight - window.innerHeight;
          const p = Math.min(Math.max(-r.top / total, 0), 1);
          const max = track.scrollWidth - window.innerWidth + 96;
          target = p * max;
          current += (target - current) * 0.085;
          track.style.transform = `translate3d(${-current}px,0,0)`;
          if (bar) bar.style.width = p * 100 + "%";
        }
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);

    return () => {
      io.disconnect();
      window.removeEventListener("mousemove", onMove);
      cancelAnimationFrame(rafId);
      lenis?.destroy();
    };
  }, []);

  return (
    <>
      <nav>
        <a className="wordmark" href="#">
          VETO<span>.</span>
        </a>
        <div className="nav-links">
          <a href="#capabilities">Capabilities</a>
          <a href="#exhibit">Exhibit</a>
          <a href="#integrate">Integrate</a>
          <a href="/console" className="nav-cta">
            Open console
          </a>
        </div>
      </nav>

      {/* HERO */}
      <header className="hero">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="hero-bg" src="/hero-figure.png" alt="" />

        <div className="hero-copy">
          <div className="hero-eyebrow rv">
            Pre-signature verification for autonomous agents
          </div>
          <h1 className="rv d1">
            Look at the intent,
            <br />
            <em>not just the transaction.</em>
          </h1>
          <p className="hero-sub rv d2">
            Agents propose. VETO simulates every transaction, diffs stated
            intent against real effect, and returns a proven verdict — before
            anything is signed.
          </p>
          <div className="hero-ctas rv d3">
            <a className="btn btn-primary" href="/console">
              Request a verdict
            </a>
            <a className="btn btn-ghost" href="#capabilities">
              See how it rules
            </a>
          </div>
        </div>

        <div className="scene" id="scene">
          <div className="panelcard pc1" data-depth="26">
            <div className="ph">
              Ruling <span className="chip allow">ALLOW</span>
            </div>
            <h4>Escrow release · task #8812</h4>
            <div className="rows">
              <div className="r">
                <span className="k">Divergence</span>
                <span className="v">0 effects</span>
              </div>
              <div className="r">
                <span className="k">Latency</span>
                <span className="v">1.1s</span>
              </div>
              <div className="r">
                <span className="k">Attested</span>
                <span className="v">0x9f2c…04ba</span>
              </div>
            </div>
          </div>
          <div className="panelcard pc2" data-depth="14">
            <div className="ph">
              Ruling <span className="chip veto">VETO</span>
            </div>
            <h4>&ldquo;Swap 50 USDT for OKB.&rdquo;</h4>
            <div className="rows">
              <div className="r">
                <span className="k">USDT out</span>
                <span className="v">− 50.00</span>
              </div>
              <div className="r bad">
                <span className="k">Approval granted</span>
                <span className="v">∞ → drainer</span>
              </div>
              <div className="r">
                <span className="k">Verdict</span>
                <span className="v" style={{ color: "var(--crimson)" }}>
                  signature refused
                </span>
              </div>
            </div>
          </div>
          <div className="panelcard pc3" data-depth="30">
            <div className="ph">
              Ruling <span className="chip warn">WARN</span>
            </div>
            <h4>Swap 800 USDT · WOKB</h4>
            <div className="rows">
              <div className="r">
                <span className="k">Slippage</span>
                <span className="v">4.6% &gt; profile</span>
              </div>
              <div className="r">
                <span className="k">Policy</span>
                <span className="v">degen-loose</span>
              </div>
            </div>
          </div>

          <div className="fig-shadow"></div>
        </div>

        <div className="hero-index">
          <b>01</b> 02 03 04{" "}
          <span
            style={{
              marginLeft: 12,
              fontSize: "10.5px",
              letterSpacing: ".22em",
              textTransform: "uppercase",
            }}
          >
            Live rulings
          </span>
        </div>
        <div className="scroll-hint">Scroll to explore</div>
      </header>

      {/* STATEMENT */}
      <section className="statement">
        <div className="kicker rv">The unguarded moment</div>
        <h2 className="rv d1">
          Every autonomous transaction
          <br />
          is signed in the dark.
        </h2>
        <p className="rv d2">
          An agent holds a wallet, receives a task, and signs — without eyes,
          without doubt, without appeal. The only moment a mistake can be caught
          is the moment before the signature. That moment now has a name.
        </p>
      </section>

      {/* HANDS / TOKEN EXCHANGE */}
      <section className="hands">
        <div className="hands-sky"></div>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="hands-img" src="/hands-sky.png" alt="" />
        <div className="token-stack rv">
          <div className="trow">
            <span className="tico" style={{ background: "#2E3A4E" }}>
              OKB
            </span>
            <div className="tname">
              <b>OKB</b>
              <span>X Layer</span>
            </div>
            <div className="tval">
              <b>$52.14</b>
              <span className="chip allow" style={{ fontSize: 9 }}>
                verified
              </span>
            </div>
          </div>
          <div className="trow">
            <span className="tico" style={{ background: "#8A6B2E" }}>
              BTC
            </span>
            <div className="tname">
              <b>Bitcoin</b>
              <span>BTC</span>
            </div>
            <div className="tval">
              <b>$4,235.17</b>
              <span className="chip allow" style={{ fontSize: 9 }}>
                verified
              </span>
            </div>
          </div>
          <div className="trow">
            <span className="tico" style={{ background: "#4E5F78" }}>
              ETH
            </span>
            <div className="tname">
              <b>Ethereum</b>
              <span>ETH</span>
            </div>
            <div className="tval">
              <b>$1,250.08</b>
              <span className="chip warn" style={{ fontSize: 9 }}>
                warn
              </span>
            </div>
          </div>
          <div className="trow">
            <span className="tico" style={{ background: "#3E7A64" }}>
              SOL
            </span>
            <div className="tname">
              <b>Solana</b>
              <span>SOL</span>
            </div>
            <div className="tval">
              <b>$212.40</b>
              <span className="chip veto" style={{ fontSize: 9 }}>
                refused
              </span>
            </div>
          </div>
        </div>
        <div className="hands-caption rv d1">
          Every hand-off between agents, verified in the middle.
        </div>
      </section>

      {/* HORIZONTAL SLIDES */}
      <section className="hslides" id="capabilities" ref={hslidesRef}>
        <div className="stick">
          <div className="hs-head">
            <div className="kicker rv">One engine · five instruments</div>
            <h2 className="rv d1">
              Everything a machine must decide,
              <br />
              verified before it acts.
            </h2>
          </div>
          <div className="track" id="track" ref={trackRef}>
            {[
              {
                idx: "/verdict · 01",
                h: "Pre-signature verdicts",
                p: "An unsigned transaction goes in. VETO forks X Layer at the current block, executes the exact state transition, and rules ALLOW, WARN or VETO — structured, deterministic, in under three seconds. A red verdict refuses to sign, by design.",
                foot: "Pay-per-ruling · x402",
                go: "Request →",
              },
              {
                idx: "/approvals · 02",
                h: "Approval hygiene",
                p: "Live allowances audited across a wallet, ranked by drain exposure, with revocation transactions generated on demand — and each revocation is verified by the engine itself before it is ever signed.",
                foot: "Continuous or on-demand",
                go: "Sweep →",
              },
              {
                idx: "/payload · 03",
                h: "Task-payload screening",
                p: "Before an agent accepts a job from the marketplace, VETO screens the inbound payload for injection and drain patterns. The work is judged before the worker is exposed to it.",
                foot: "Marketplace-native",
                go: "Screen →",
              },
              {
                idx: "/counterparty · 04",
                h: "Counterparty pre-check",
                p: "An evidence-graded ruling on any address or contract before negotiation begins — bytecode, ownership, liquidity posture, incident history — every claim carrying an on-chain reference.",
                foot: "Sub-second",
                go: "Check →",
              },
              {
                idx: "/forensics · 05",
                h: "Post-incident forensics",
                p: "Replay any historical transaction through the engine and see, precisely, what should have been caught — an evidence-grade report for protocols, treasuries and auditors after any exploit.",
                foot: "Any block, any tx",
                go: "Replay →",
              },
            ].map((s) => (
              <div className="slide" key={s.idx}>
                <div className="idx">{s.idx}</div>
                <h3>{s.h}</h3>
                <p>{s.p}</p>
                <div className="foot">
                  <span>{s.foot}</span>
                  <a className="go" href="#">
                    {s.go}
                  </a>
                </div>
              </div>
            ))}
          </div>
          <div className="hs-progress">
            <i id="hsbar" ref={barRef}></i>
          </div>
        </div>
      </section>

      {/* EXHIBIT */}
      <section className="exhibit" id="exhibit">
        <div className="inner">
          <div className="kicker2 rv">Exhibit A</div>
          <h2 className="rv d1">Intent, versus effect.</h2>
          <p className="lede rv d2">
            The agent declared a swap. The simulation found something else. A
            real verdict, rendered in 1.8 seconds and attested on X Layer.
          </p>
          <div className="stage rv d2">
            <div className="pane">
              <div className="pane-label">
                Declared intent{" "}
                <span className="dot" style={{ background: "var(--slate)" }}></span>
              </div>
              <p className="intent-line">
                &ldquo;Swap 50 USDT for OKB to settle task&nbsp;#4412.&rdquo;
              </p>
              <div className="effect-rows" style={{ marginTop: 30 }}>
                <div className="effect-row">
                  <span className="k">Origin agent</span>
                  <span className="v">okx.ai / #4127</span>
                </div>
                <div className="effect-row">
                  <span className="k">Chain</span>
                  <span className="v">X Layer · 196</span>
                </div>
                <div className="effect-row">
                  <span className="k">Policy profile</span>
                  <span className="v">treasury-strict</span>
                </div>
              </div>
            </div>
            <div className="pane">
              <div className="pane-label">
                Simulated effect{" "}
                <span className="dot" style={{ background: "var(--crimson)" }}></span>
              </div>
              <div className="effect-rows">
                <div className="effect-row">
                  <span className="k">USDT out</span>
                  <span className="v">− 50.00</span>
                </div>
                <div className="effect-row">
                  <span className="k">OKB in</span>
                  <span className="v">+ 0.9384</span>
                </div>
                <div className="effect-row flag">
                  <span className="k">Approval granted</span>
                  <span className="v">USDT → 0x7f9…c41 · unlimited</span>
                </div>
                <div className="effect-row flag">
                  <span className="k">Spender reputation</span>
                  <span className="v">drainer cluster · 14 incidents</span>
                </div>
                <div className="effect-row">
                  <span className="k">Divergence from intent</span>
                  <span className="v" style={{ color: "var(--crimson)" }}>
                    2 undeclared effects
                  </span>
                </div>
              </div>
            </div>
            <div className="stage-verdict">
              <div className="seal">
                <div className="seal-ring">
                  <span className="serif">VETO</span>
                </div>
                <div className="seal-copy">
                  <span className="serif">Signature refused.</span>
                  <p>
                    The transaction performs the declared swap — and quietly
                    grants an unlimited allowance to a known drainer. Intent and
                    effect diverge. The verdict is final, and it is proven.
                  </p>
                </div>
              </div>
              <div className="seal-meta">
                verdict &nbsp;<b>VETO — 2 findings</b>
                <br />
                simulated at block &nbsp;<b>#9,412,336</b>
                <br />
                evidence &nbsp;<b>0x3ac1…88f2</b>
                <br />
                attested on X Layer &nbsp;<b>tx 0xb04d…71ce</b>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* INTEGRATE */}
      <section className="integrate" id="integrate">
        <div className="inner">
          <div className="kicker2 rv">Integration</div>
          <h2
            className="rv d1"
            style={{
              fontFamily: "'Newsreader',serif",
              fontWeight: 400,
              fontSize: "clamp(34px,4.4vw,56px)",
              letterSpacing: "-.01em",
            }}
          >
            Ten lines between an agent
            <br />
            and a mistake.
          </h2>
          <div className="int-grid">
            <pre className="codeblock rv d1">
              <span className="c">
                {"// wrap any signer — every tx routes through VETO"}
              </span>
              {"\n"}
              <span className="y">import</span> {"{ guard } "}
              <span className="y">from</span>{" "}
              <span className="g">&quot;@veto/sdk&quot;</span>;{"\n\n"}
              <span className="y">const</span> signer = guard(agentSigner, {"{"}
              {"\n"}
              {"  policy: "}
              <span className="g">&quot;treasury-strict&quot;</span>,{"\n"}
              {"  onVerdict: (v) => audit.log(v)"}
              {"\n"}
              {"});"}
              {"\n\n"}
              <span className="c">
                {"// a red verdict refuses to sign — by design"}
              </span>
              {"\n"}
              <span className="y">await</span> signer.sendTransaction(tx);{"\n"}
              <span className="r">
                {"// ✗ VETO — undeclared unlimited approval"}
              </span>
            </pre>
            <div className="int-copy rv d2">
              <h3>Three ways in.</h3>
              <p>
                Whether it is a single pay-per-call ruling or an always-on
                guardianship of an entire treasury, the engine is the same. The
                commitment scales with you.
              </p>
              <div className="paths">
                <div className="path">
                  <b>Marketplace</b>
                  <span>
                    A2MCP endpoint on OKX.AI — any agent pays per verdict in USDT
                    via x402. No account, no key. The payment is the auth.
                  </span>
                </div>
                <div className="path">
                  <b>SDK middleware</b>
                  <span>
                    guard(signer) around any agent. Red verdicts refuse to sign.
                    Ten lines to integrate.
                  </span>
                </div>
                <div className="path">
                  <b>Always-on watch</b>
                  <span>
                    Register agent wallets; VETO monitors, alerts, and attests
                    continuously.
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* MARKET PANEL */}
      <section className="market">
        <div className="market-sky"></div>
        <div className="market-card rv">
          <div className="mhead">
            <div>
              <div className="mk">Screened volume</div>
              <div className="mv">$498,098.00</div>
            </div>
            <span className="chip allow">engine live</span>
          </div>
          <div className="mbars" aria-hidden="true">
            <i style={{ height: "38%" }}></i>
            <i style={{ height: "56%" }}></i>
            <i style={{ height: "44%" }}></i>
            <i style={{ height: "72%" }}></i>
            <i className="hot" style={{ height: "92%" }}></i>
            <i style={{ height: "60%" }}></i>
            <i style={{ height: "50%" }}></i>
          </div>
          <div className="mdays">
            <span>Mon</span>
            <span>Tue</span>
            <span>Wed</span>
            <span>Thu</span>
            <span>Fri</span>
            <span>Sat</span>
            <span>Sun</span>
          </div>
          <div className="mport">
            <div className="mrow">
              <span className="tico" style={{ background: "#8A6B2E" }}>
                BTC
              </span>
              <b>Bitcoin</b>
              <span className="mp">
                $4,235.17 <i className="up2">+1.00%</i>
              </span>
            </div>
            <div className="mrow">
              <span className="tico" style={{ background: "#4E5F78" }}>
                ETH
              </span>
              <b>Ethereum</b>
              <span className="mp">
                $1,250.08 <i className="dn2">−0.18%</i>
              </span>
            </div>
            <div className="mrow">
              <span className="tico" style={{ background: "#3E7A64" }}>
                SOL
              </span>
              <b>Solana</b>
              <span className="mp">
                $212.40 <i className="up2">+5.23%</i>
              </span>
            </div>
            <div className="mrow">
              <span className="tico" style={{ background: "#2E3A4E" }}>
                OKB
              </span>
              <b>OKB</b>
              <span className="mp">
                $52.14 <i className="up2">+2.41%</i>
              </span>
            </div>
          </div>
        </div>
        <div className="hands-caption rv d1">
          Every ruling, every market, one honest ledger.
        </div>
      </section>

      {/* FINAL */}
      <section className="final">
        <div
          className="kicker rv"
          style={{
            fontSize: 11,
            letterSpacing: ".3em",
            textTransform: "uppercase",
            color: "var(--ink-2)",
            marginBottom: 28,
          }}
        >
          The standard
        </div>
        <h2 className="serif rv d1">
          Agents propose.
          <br />
          VETO disposes.
        </h2>
        <p className="rv d2">
          The verdict layer of the agent economy — live on X Layer, listed on
          OKX.AI, priced per ruling.
        </p>
        <div className="hero-ctas rv d3">
          <a className="btn btn-primary" href="/console">
            Request a verdict
          </a>
          <a className="btn btn-ghost" href="/dashboard">
            View attestation ledger
          </a>
        </div>
      </section>

      <footer>
        <div className="foot-grid">
          <div>
            <div className="wm">
              VETO<span>.</span>
            </div>
            <p
              style={{
                color: "var(--ink-3)",
                fontSize: "12.5px",
                marginTop: 16,
                maxWidth: 280,
                lineHeight: 1.7,
              }}
            >
              Pre-signature verification infrastructure for autonomous agents.
              Simulate. Diff. Prove.
            </p>
          </div>
          <div className="foot-cols">
            <div className="foot-col">
              <b>Product</b>
              <a href="#">Console</a>
              <a href="#">Verdict API</a>
              <a href="#">SDK</a>
              <a href="#">Attestation ledger</a>
            </div>
            <div className="foot-col">
              <b>Doctrine</b>
              <a href="#">How verdicts work</a>
              <a href="#">Evidence format</a>
              <a href="#">Policy profiles</a>
            </div>
            <div className="foot-col">
              <b>Network</b>
              <a href="#">OKX.AI listing</a>
              <a href="#">X Layer contract</a>
              <a href="#">Status</a>
            </div>
          </div>
        </div>
        <div className="foot-base">
          <span>© 2026 VETO. Rendered on X Layer.</span>
          <span className="mono" style={{ fontSize: 11 }}>
            attestation contract 0x51ab…9e04
          </span>
        </div>
      </footer>
    </>
  );
}
VETO_FILE_1_END_9f3a

# ---------- remotion/src/Handoff.tsx ----------
cat > remotion/src/Handoff.tsx << 'VETO_FILE_2_END_9f3a'
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
VETO_FILE_2_END_9f3a

# ---------- remotion/src/VetoDemo.tsx ----------
cat > remotion/src/VetoDemo.tsx << 'VETO_FILE_3_END_9f3a'
import React from "react";
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame, Series } from "remotion";
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
const OUTRO = 270;      // 9s   (total 1800 = 60s)

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
VETO_FILE_3_END_9f3a

# copy the hands image into remotion/public if it exists in the web app
if [ -f apps/web/public/hands-sky.png ]; then
  cp apps/web/public/hands-sky.png remotion/public/hands-sky.png
  echo "hands-sky.png copied to remotion/public/"
else
  echo ""
  echo "!! IMPORTANT: apps/web/public/hands-sky.png is MISSING."
  echo "   Save the hands image (blue sky, two hands reaching) as:"
  echo "     apps/web/public/hands-sky.png"
  echo "   then re-run this script."
fi
echo ""
echo "Done."
echo "Landing:  npm run web:dev   -> the hands section now shows the photo"
echo "Video:    cd remotion && npm install && npm run render-video"
