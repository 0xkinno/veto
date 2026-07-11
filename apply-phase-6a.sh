#!/usr/bin/env bash
# VETO — Phase 6A apply script (Next.js landing page port)
# Run from the root of your veto folder:  bash apply-phase-6a.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 6A files into $(pwd) ..."
mkdir -p apps/web/app apps/web/styles apps/web/public

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
          <a href="/dashboard" className="nav-cta">
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
            <a className="btn btn-primary" href="#">
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
          <a className="btn btn-primary" href="#">
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

# ---------- apps/web/app/layout.tsx ----------
cat > apps/web/app/layout.tsx << 'VETO_FILE_2_END_9f3a'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "VETO — The last word before the chain",
  description:
    "VETO is the pre-signature verification layer for autonomous agents. Simulate, diff, prove — before anything is signed.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin=""
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter+Tight:wght@400;500;600&family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;1,6..72,400&family=IBM+Plex+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
VETO_FILE_2_END_9f3a

# ---------- apps/web/app/globals.css ----------
cat > apps/web/app/globals.css << 'VETO_FILE_3_END_9f3a'
/* Base reset. The landing owns its full design system in styles/landing.css. */
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { background: #F4F1E9; }
VETO_FILE_3_END_9f3a

# ---------- apps/web/styles/landing.css ----------
cat > apps/web/styles/landing.css << 'VETO_FILE_4_END_9f3a'

:root{
  --ivory:#F4F1E9;
  --stone:#ECE8DD;
  --card:#FFFFFF;
  --ink:#141311;
  --ink-2:#5D584C;
  --ink-3:#948E7E;
  --line:rgba(20,19,17,.10);
  --line-soft:rgba(20,19,17,.06);
  --emerald:#2E7A57;
  --emerald-bg:rgba(46,122,87,.10);
  --amber:#9A6E1E;
  --amber-bg:rgba(154,110,30,.10);
  --crimson:#96302E;
  --crimson-bg:rgba(150,48,46,.09);
  --slate:#4E5F78;
  --sky-hi:#DDE7EE;
  --sky-mid:#C9D9E4;
  --sun:#F6EBD9;
  --ease:cubic-bezier(.22,.61,.21,1);
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{
  background:var(--ivory);
  color:var(--ink);
  font-family:'Inter Tight',-apple-system,BlinkMacSystemFont,sans-serif;
  -webkit-font-smoothing:antialiased;
  overflow-x:hidden;
}
::selection{background:var(--crimson);color:#fff}
.serif{font-family:'Newsreader',Georgia,serif}
.mono{font-family:'IBM Plex Mono',monospace}

/* reveal */
.rv{opacity:0;transform:translateY(30px);transition:opacity 1.2s var(--ease),transform 1.2s var(--ease)}
.rv.in{opacity:1;transform:none}
.rv.d1{transition-delay:.14s}.rv.d2{transition-delay:.28s}.rv.d3{transition-delay:.42s}
@media(prefers-reduced-motion:reduce){.rv{opacity:1;transform:none;transition:none}}

/* ---------- nav ---------- */
nav{
  position:fixed;top:18px;left:50%;transform:translateX(-50%);z-index:100;
  display:flex;align-items:center;gap:34px;
  background:rgba(255,255,255,.72);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);
  border:1px solid rgba(20,19,17,.08);border-radius:100px;
  padding:10px 12px 10px 24px;
  box-shadow:0 4px 24px rgba(20,19,17,.06);
  transition:box-shadow .4s var(--ease);
}
nav .wordmark{font-weight:600;font-size:13px;letter-spacing:.3em;color:var(--ink);text-decoration:none}
nav .wordmark span{color:var(--crimson)}
.nav-links{display:flex;gap:26px;align-items:center}
.nav-links a{color:var(--ink-2);text-decoration:none;font-size:13px;transition:color .3s}
.nav-links a:hover{color:var(--ink)}
.nav-cta{
  background:var(--ink);color:var(--ivory)!important;font-weight:500;
  padding:9px 20px;border-radius:100px;transition:background .3s!important;
}
.nav-cta:hover{background:#2a2823}

/* ---------- hero scene ---------- */
.hero{
  position:relative;min-height:100vh;overflow:hidden;
  display:flex;flex-direction:column;align-items:center;
  padding:0 24px;
}
.sky{
  position:absolute;inset:0;
  background:
    radial-gradient(1200px 700px at 50% 88%, rgba(246,235,217,.95), transparent 60%),
    radial-gradient(900px 500px at 50% 96%, rgba(240,215,180,.55), transparent 55%),
    linear-gradient(180deg,var(--ivory) 0%,var(--sky-hi) 34%,var(--sky-mid) 62%,#D8DFD2 82%,#CBD3C0 100%);
}
.sun{
  position:absolute;left:50%;bottom:16%;transform:translateX(-50%);
  width:520px;height:520px;border-radius:50%;
  background:radial-gradient(circle,rgba(255,251,240,.95) 0%,rgba(250,240,218,.55) 38%,transparent 70%);
  filter:blur(2px);pointer-events:none;
}
.ground{
  position:absolute;left:-10%;right:-10%;bottom:-12%;height:36%;
  background:linear-gradient(180deg,rgba(178,190,160,.0),rgba(150,164,132,.55) 42%,rgba(120,134,104,.75));
  border-radius:50% 50% 0 0 / 100% 100% 0 0;
}
.hero-copy{position:relative;z-index:6;text-align:center;padding-top:132px}
.hero-eyebrow{
  font-size:11.5px;letter-spacing:.3em;text-transform:uppercase;color:var(--ink-2);
  margin-bottom:26px;
}
.hero h1{
  font-family:'Newsreader',serif;font-weight:400;
  font-size:clamp(46px,7vw,96px);line-height:1.03;letter-spacing:-.015em;color:var(--ink);
}
.hero h1 em{font-style:italic}
.hero-sub{margin:24px auto 0;max-width:520px;color:var(--ink-2);font-size:16.5px;line-height:1.65}
.hero-ctas{margin-top:36px;display:flex;gap:14px;justify-content:center;flex-wrap:wrap}
.btn{
  font-family:inherit;font-size:14px;font-weight:500;padding:14px 30px;border-radius:100px;
  cursor:pointer;text-decoration:none;display:inline-flex;align-items:center;gap:10px;
  transition:transform .3s var(--ease),background .3s,border-color .3s,box-shadow .3s;
}
.btn:active{transform:scale(.97)}
.btn-primary{background:var(--ink);color:var(--ivory);border:1px solid var(--ink)}
.btn-primary:hover{background:#2a2823;box-shadow:0 8px 24px rgba(20,19,17,.18)}
.btn-ghost{background:rgba(255,255,255,.65);color:var(--ink);border:1px solid rgba(20,19,17,.14);backdrop-filter:blur(8px)}
.btn-ghost:hover{background:#fff}

/* floating verdict panels + figure */
.scene{
  position:relative;z-index:4;width:100%;max-width:1300px;flex:1;min-height:56vh;margin-top:16px;
}
.panelcard{
  position:absolute;background:rgba(255,255,255,.92);backdrop-filter:blur(6px);
  border:1px solid rgba(20,19,17,.07);border-radius:16px;
  box-shadow:0 18px 60px rgba(60,70,60,.16);
  padding:22px 24px;width:280px;
  will-change:transform;
  transition:transform .2s linear;
}
.panelcard .ph{font-size:10.5px;letter-spacing:.18em;text-transform:uppercase;color:var(--ink-3);margin-bottom:12px;display:flex;justify-content:space-between;align-items:center}
.panelcard h4{font-size:16px;font-weight:500;line-height:1.35;margin-bottom:8px}
.panelcard p{font-size:12.5px;color:var(--ink-2);line-height:1.6}
.panelcard .rows{margin-top:12px;display:flex;flex-direction:column}
.panelcard .r{display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid var(--line-soft);font-size:11.5px}
.panelcard .r:last-child{border-bottom:none}
.panelcard .r .k{color:var(--ink-3)}
.panelcard .r .v{font-family:'IBM Plex Mono',monospace;font-size:10.5px;color:var(--ink-2)}
.panelcard .r.bad .k,.panelcard .r.bad .v{color:var(--crimson)}
.chip{font-size:10px;font-weight:600;letter-spacing:.14em;padding:3.5px 10px;border-radius:100px;white-space:nowrap}
.chip.allow{color:var(--emerald);background:var(--emerald-bg)}
.chip.warn{color:var(--amber);background:var(--amber-bg)}
.chip.veto{color:var(--crimson);background:var(--crimson-bg)}
.pc1{left:2%;top:10%}
.pc2{left:50%;transform:translateX(-50%);bottom:-2%;width:290px;z-index:5}
.pc3{right:2%;top:16%}
.hero-bg{
  position:absolute;inset:0;width:100%;height:100%;
  object-fit:cover;object-position:center bottom;z-index:1;
  -webkit-mask-image:linear-gradient(180deg,transparent 0%,#000 18%);
  mask-image:linear-gradient(180deg,transparent 0%,#000 18%);
}
.hero::before{content:"";position:absolute;inset:0;z-index:2;pointer-events:none;
  background:linear-gradient(180deg,rgba(243,241,236,.96) 0%,rgba(240,240,238,.8) 26%,rgba(242,241,236,.35) 44%,rgba(244,241,233,0) 58%);}
.hero::after{content:"";position:absolute;left:50%;bottom:6%;transform:translateX(-50%);
  width:760px;height:640px;z-index:2;pointer-events:none;
  background:radial-gradient(closest-side,rgba(255,243,214,.75) 0%,rgba(255,240,208,.35) 42%,transparent 72%);}
.fig-shadow{
  position:absolute;left:50%;bottom:-8px;transform:translateX(-50%);
  width:130px;height:20px;border-radius:50%;
  background:radial-gradient(ellipse,rgba(40,48,36,.35),transparent 70%);
  z-index:5;
}
.scroll-hint{
  position:absolute;bottom:28px;right:40px;z-index:7;
  font-size:10.5px;letter-spacing:.26em;text-transform:uppercase;color:var(--ink-2);
  display:flex;align-items:center;gap:10px;
}
.scroll-hint::after{content:"→";font-size:14px}
.hero-index{
  position:absolute;bottom:28px;left:40px;z-index:7;
  font-size:12px;color:var(--ink-2);letter-spacing:.06em;display:flex;gap:16px;align-items:baseline;
}
.hero-index b{color:var(--ink);font-weight:500}

/* ---------- statement section (sky chapter) ---------- */
.statement{
  min-height:92vh;display:flex;flex-direction:column;justify-content:center;align-items:center;
  text-align:center;position:relative;padding:120px 24px;overflow:hidden;
  background:linear-gradient(180deg,#CBD3C0 0%,var(--sky-mid) 18%,var(--sky-hi) 50%,var(--ivory) 100%);
}
.statement .kicker{font-size:11px;letter-spacing:.3em;text-transform:uppercase;color:var(--ink-2);margin-bottom:30px}
.statement h2{
  font-family:'Newsreader',serif;font-weight:400;
  font-size:clamp(40px,6vw,80px);line-height:1.08;letter-spacing:-.012em;max-width:980px;color:var(--ink);
}
.statement p{margin-top:28px;max-width:540px;color:var(--ink-2);font-size:16.5px;line-height:1.7}

/* ---------- hands / token exchange ---------- */
.hands,.market{
  position:relative;min-height:100vh;display:flex;flex-direction:column;
  justify-content:center;align-items:center;overflow:hidden;padding:90px 24px;
}
.hands-sky,.market-sky{
  position:absolute;inset:0;
  background:
    radial-gradient(900px 460px at 50% 108%, rgba(246,235,217,.85), transparent 60%),
    linear-gradient(180deg,var(--ivory) 0%,var(--sky-hi) 40%,var(--sky-mid) 100%);
}
.market-sky{
  background:
    radial-gradient(900px 460px at 50% 112%, rgba(246,231,208,.9), transparent 62%),
    linear-gradient(180deg,var(--sky-mid) 0%,var(--sky-hi) 46%,var(--ivory) 100%);
}
.hands-img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:2;
  -webkit-mask-image:linear-gradient(180deg,transparent 0%,#000 12%,#000 88%,transparent 100%);
  mask-image:linear-gradient(180deg,transparent 0%,#000 12%,#000 88%,transparent 100%);}
.token-stack{
  position:relative;z-index:5;display:flex;flex-direction:column;gap:13px;width:min(430px,86vw);
}
.trow{
  display:flex;align-items:center;gap:14px;
  background:rgba(255,255,255,.93);backdrop-filter:blur(8px);
  border:1px solid rgba(20,19,17,.07);border-radius:14px;
  box-shadow:0 14px 44px rgba(60,70,60,.14);padding:14px 18px;
  transition:transform .35s var(--ease),box-shadow .35s var(--ease);
}
.trow:hover{transform:translateY(-3px);box-shadow:0 20px 54px rgba(60,70,60,.18)}
.tico{
  width:34px;height:34px;border-radius:50%;flex-shrink:0;
  display:flex;align-items:center;justify-content:center;
  color:#fff;font-size:9.5px;font-weight:600;letter-spacing:.04em;
}
.tname{display:flex;flex-direction:column;gap:2px;flex:1}
.tname b{font-size:14px;font-weight:500}
.tname span{font-size:11px;color:var(--ink-3)}
.tval{display:flex;flex-direction:column;align-items:flex-end;gap:4px}
.tval b{font-size:13.5px;font-weight:500;font-variant-numeric:tabular-nums}
.hands-caption{
  position:relative;z-index:4;margin-top:44px;
  font-family:'Newsreader',serif;font-style:italic;font-size:clamp(19px,2.4vw,26px);color:#fff;text-shadow:0 2px 16px rgba(20,40,70,.4);
  text-align:center;
}

/* ---------- market panel ---------- */
.market-card{
  position:relative;z-index:4;width:min(520px,92vw);
  background:rgba(255,255,255,.95);backdrop-filter:blur(8px);
  border:1px solid rgba(20,19,17,.07);border-radius:18px;
  box-shadow:0 24px 70px rgba(60,70,60,.16);padding:28px 30px;
}
.mhead{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:22px}
.mk{font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--ink-3);font-weight:500}
.mv{font-size:28px;font-weight:500;letter-spacing:-.02em;margin-top:8px;font-variant-numeric:tabular-nums}
.mbars{height:110px;display:flex;align-items:flex-end;gap:10px;padding:0 4px}
.mbars i{flex:1;background:rgba(20,19,17,.10);border-radius:5px 5px 2px 2px}
.mbars i.hot{background:var(--slate)}
.mdays{display:flex;justify-content:space-between;padding:10px 4px 18px;border-bottom:1px solid var(--line-soft)}
.mdays span{font-size:10.5px;color:var(--ink-3)}
.mport{display:flex;flex-direction:column;padding-top:6px}
.mrow{display:flex;align-items:center;gap:12px;padding:12px 0;border-bottom:1px solid var(--line-soft);font-size:13.5px}
.mrow:last-child{border-bottom:none}
.mrow b{font-weight:500;flex:1}
.mp{font-variant-numeric:tabular-nums;color:var(--ink-2);font-size:13px}
.mp i{font-style:normal;font-size:11.5px;margin-left:8px}
.up2{color:var(--emerald)}
.dn2{color:var(--crimson)}
@media(max-width:960px){.hand{display:none}}

/* ---------- horizontal slides ---------- */
.hslides{position:relative;height:420vh}
.hslides .stick{position:sticky;top:0;height:100vh;overflow:hidden;display:flex;flex-direction:column;justify-content:center}
.hs-head{padding:0 48px;max-width:1240px;margin:0 auto 44px;width:100%}
.hs-head .kicker{font-size:11px;letter-spacing:.3em;text-transform:uppercase;color:var(--ink-2);margin-bottom:18px}
.hs-head h2{font-family:'Newsreader',serif;font-weight:400;font-size:clamp(32px,4vw,52px);letter-spacing:-.01em}
.track{
  display:flex;gap:22px;padding:0 48px;width:max-content;
  will-change:transform;
}
.slide{
  width:min(420px,78vw);flex-shrink:0;background:var(--card);
  border:1px solid var(--line-soft);border-radius:18px;
  box-shadow:0 14px 50px rgba(60,70,60,.10);
  padding:34px 34px 30px;display:flex;flex-direction:column;min-height:340px;
}
.slide .idx{font-family:'IBM Plex Mono',monospace;font-size:11px;color:var(--ink-3);margin-bottom:20px}
.slide h3{font-family:'Newsreader',serif;font-weight:400;font-size:27px;letter-spacing:-.01em;margin-bottom:14px}
.slide p{font-size:14px;color:var(--ink-2);line-height:1.7;flex:1}
.slide .foot{
  margin-top:24px;padding-top:18px;border-top:1px solid var(--line-soft);
  display:flex;justify-content:space-between;align-items:center;font-size:12px;color:var(--ink-3);
}
.slide .foot .go{color:var(--ink);font-weight:500;text-decoration:none;font-size:13px}
.hs-progress{
  margin:44px auto 0;max-width:1240px;width:calc(100% - 96px);
  height:2px;background:rgba(20,19,17,.08);border-radius:100px;overflow:hidden;
}
.hs-progress i{display:block;height:100%;width:0;background:var(--ink);border-radius:100px}

/* ---------- exhibit ---------- */
.exhibit{padding:150px 48px;background:var(--ivory)}
.exhibit .inner{max-width:1180px;margin:0 auto}
.kicker2{font-size:11px;letter-spacing:.3em;text-transform:uppercase;color:var(--ink-2);margin-bottom:24px;display:flex;align-items:center;gap:14px}
.kicker2::before{content:"";width:26px;height:1px;background:var(--crimson)}
.exhibit h2{font-family:'Newsreader',serif;font-weight:400;font-size:clamp(34px,4.4vw,56px);letter-spacing:-.01em;max-width:760px}
.exhibit .lede{margin-top:22px;max-width:560px;color:var(--ink-2);font-size:16px;line-height:1.7}
.stage{
  margin-top:70px;display:grid;grid-template-columns:1fr 1fr;gap:1px;
  background:var(--line);border:1px solid var(--line);border-radius:18px;overflow:hidden;
  box-shadow:0 20px 70px rgba(60,70,60,.10);
}
.pane{background:var(--card);padding:38px}
.pane-label{font-size:10.5px;letter-spacing:.24em;text-transform:uppercase;color:var(--ink-3);margin-bottom:24px;display:flex;justify-content:space-between;align-items:center}
.dot{width:7px;height:7px;border-radius:50%;display:inline-block}
.intent-line{font-family:'Newsreader',serif;font-size:23px;line-height:1.45;font-style:italic}
.effect-rows{display:flex;flex-direction:column;margin-top:2px}
.effect-row{display:flex;justify-content:space-between;align-items:baseline;gap:18px;padding:14px 0;border-bottom:1px solid var(--line-soft);font-size:13px}
.effect-row:last-child{border-bottom:none}
.effect-row .k{color:var(--ink-3)}
.effect-row .v{font-family:'IBM Plex Mono',monospace;font-size:12px;color:var(--ink-2);text-align:right}
.effect-row.flag .k,.effect-row.flag .v{color:var(--crimson)}
.stage-verdict{
  grid-column:1/-1;background:var(--card);padding:44px 38px;
  display:flex;align-items:center;justify-content:space-between;gap:36px;flex-wrap:wrap;
}
.seal{display:flex;align-items:center;gap:26px}
.seal-ring{
  width:96px;height:96px;border-radius:50%;border:1.5px solid var(--crimson);
  display:flex;align-items:center;justify-content:center;position:relative;flex-shrink:0;
  background:var(--crimson-bg);
}
.seal-ring::before{content:"";position:absolute;inset:6px;border-radius:50%;border:1px solid rgba(150,48,46,.35)}
.seal-ring .serif{font-size:17px;letter-spacing:.18em;color:var(--crimson);font-weight:500}
.seal-copy .serif{font-size:24px;font-style:italic;display:block;margin-bottom:8px}
.seal-copy p{color:var(--ink-2);font-size:13.5px;max-width:420px;line-height:1.65}
.seal-meta{font-family:'IBM Plex Mono',monospace;font-size:11.5px;color:var(--ink-3);line-height:2;text-align:right}
.seal-meta b{color:var(--ink);font-weight:500}

/* ---------- integrate ---------- */
.integrate{padding:150px 48px;background:linear-gradient(180deg,var(--ivory),var(--stone))}
.integrate .inner{max-width:1180px;margin:0 auto}
.int-grid{margin-top:70px;display:grid;grid-template-columns:1fr 1fr;gap:70px;align-items:center}
.codeblock{
  background:#1D1C19;border-radius:16px;padding:28px 30px;
  font-family:'IBM Plex Mono',monospace;font-size:12.5px;line-height:1.9;color:#D8D3C4;
  overflow-x:auto;box-shadow:0 24px 70px rgba(40,44,36,.25);
}
.codeblock .c{color:#777263}
.codeblock .g{color:#8FC9A8}
.codeblock .r{color:#E09492}
.codeblock .y{color:#D9BC7E}
.int-copy h3{font-family:'Newsreader',serif;font-weight:400;font-size:30px;margin-bottom:18px}
.int-copy p{color:var(--ink-2);font-size:15px;line-height:1.75;margin-bottom:24px}
.paths{display:flex;flex-direction:column;border-top:1px solid var(--line)}
.path{display:flex;gap:18px;padding:18px 0;border-bottom:1px solid var(--line);font-size:13.5px}
.path b{min-width:140px;font-weight:500}
.path span{color:var(--ink-2);line-height:1.6}

/* ---------- final ---------- */
.final{
  min-height:90vh;display:flex;flex-direction:column;justify-content:center;align-items:center;
  text-align:center;position:relative;overflow:hidden;padding:120px 24px;
  background:
    radial-gradient(1000px 600px at 50% 100%, rgba(246,235,217,.9), transparent 62%),
    linear-gradient(180deg,var(--stone),var(--sky-hi) 55%,var(--sky-mid));
}
.final h2{font-family:'Newsreader',serif;font-weight:400;font-size:clamp(42px,6vw,84px);line-height:1.05;max-width:900px;letter-spacing:-.012em}
.final p{margin-top:26px;color:var(--ink-2);max-width:460px;font-size:16px;line-height:1.7}

/* ---------- footer ---------- */
footer{background:var(--ivory);border-top:1px solid var(--line);padding:72px 48px 52px}
.foot-grid{max-width:1180px;margin:0 auto;display:flex;justify-content:space-between;gap:48px;flex-wrap:wrap}
.foot-grid .wm{font-weight:600;font-size:13px;letter-spacing:.3em}
.foot-grid .wm span{color:var(--crimson)}
.foot-cols{display:flex;gap:80px;flex-wrap:wrap}
.foot-col{display:flex;flex-direction:column;gap:13px}
.foot-col b{font-size:11px;letter-spacing:.2em;text-transform:uppercase;color:var(--ink-3);font-weight:500;margin-bottom:5px}
.foot-col a{color:var(--ink-2);text-decoration:none;font-size:13px;transition:color .3s}
.foot-col a:hover{color:var(--ink)}
.foot-base{
  max-width:1180px;margin:56px auto 0;padding-top:26px;border-top:1px solid var(--line-soft);
  display:flex;justify-content:space-between;gap:20px;flex-wrap:wrap;color:var(--ink-3);font-size:12px;
}

@media(max-width:960px){
  nav{gap:14px;padding:9px 10px 9px 18px;top:12px;width:calc(100% - 24px);justify-content:space-between}
  .nav-links a:not(.nav-cta){display:none}
  .hero-copy{padding-top:120px}
  .scene{height:52vh}
  .pc1{left:-6%;top:2%;transform:scale(.86)}
  .pc3{right:-6%;top:4%;transform:scale(.86)}
  .pc2{width:280px}
  .hero-index,.scroll-hint{display:none}
  .exhibit,.integrate{padding:100px 22px}
  .stage{grid-template-columns:1fr}
  .int-grid{grid-template-columns:1fr;gap:42px}
  .seal-meta{text-align:left}
  .hs-head{padding:0 22px}
  .track{padding:0 22px}
  .hs-progress{width:calc(100% - 44px)}
}

/* ---------- mobile polish (phone) ---------- */
@media(max-width:640px){
  .hero-copy{padding-top:104px}
  .hero h1{font-size:clamp(38px,10vw,56px)}
  .hero-sub{font-size:15px;max-width:340px}
  .scene{min-height:60vh;margin-top:8px}
  /* stack the floating verdict cards into a readable column, no absolute overlap */
  .scene{display:flex;flex-direction:column;align-items:center;gap:16px;position:relative}
  .panelcard{position:relative !important;left:auto !important;right:auto !important;top:auto !important;bottom:auto !important;transform:none !important;width:min(340px,90vw) !important}
  .pc2{transform:none !important}
  .fig-shadow{display:none}
  .statement{min-height:auto;padding:90px 22px}
  .statement h2{font-size:clamp(32px,8vw,44px)}
  .hands,.market{min-height:auto;padding:80px 20px}
  .token-stack{width:min(360px,92vw)}
  .hands-caption{font-size:18px;margin-top:32px}
  /* horizontal deck becomes a natural vertical stack on touch */
  .hslides{height:auto !important}
  .hslides .stick{position:relative !important;height:auto !important;top:auto !important;display:block;padding:80px 0}
  .track{transform:none !important;flex-direction:column;width:100% !important;padding:0 20px;gap:16px}
  .slide{width:100% !important;min-height:auto}
  .hs-progress{display:none}
  .hs-head{margin-bottom:28px;padding:0 20px}
  .exhibit,.integrate{padding:80px 20px}
  .exhibit h2,.integrate h2{font-size:clamp(30px,8vw,40px)}
  .stage{grid-template-columns:1fr}
  .stage-verdict{flex-direction:column;align-items:flex-start;gap:24px;padding:32px 24px}
  .seal{flex-direction:column;align-items:flex-start;gap:18px}
  .seal-meta{text-align:left}
  .int-grid{grid-template-columns:1fr;gap:36px}
  .codeblock{font-size:11.5px;padding:22px}
  .market-card{padding:22px}
  .mv{font-size:24px}
  .final{min-height:auto;padding:90px 22px}
  .final h2{font-size:clamp(38px,10vw,56px)}
  footer{padding:56px 22px 40px}
  .foot-cols{gap:40px}
  .foot-grid{gap:32px}
}

/* respect reduced motion across the whole page */
@media(prefers-reduced-motion:reduce){
  .track{transition:none}
  html{scroll-behavior:auto}
}
VETO_FILE_4_END_9f3a

# ---------- apps/web/package.json ----------
cat > apps/web/package.json << 'VETO_FILE_5_END_9f3a'
{
  "name": "@veto/web",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "gsap": "^3.12.5",
    "next": "14.2.35",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "lenis": "^1.1.13"
  },
  "devDependencies": {
    "@types/node": "^20.16.5",
    "@types/react": "^18.3.5",
    "@types/react-dom": "^18.3.0",
    "typescript": "^5.6.2"
  }
}
VETO_FILE_5_END_9f3a

# ---------- docs/CHECKLIST.md ----------
cat > docs/CHECKLIST.md << 'VETO_FILE_6_END_9f3a'
# VETO — Master Build Checklist

Tick each item as it is completed and tested against live infrastructure. Do not advance a phase until every box in it is checked. One build, modified forward — never regenerated.

---

## Phase 0 — Scaffold  ✅ (this zip)

- [x] Monorepo structure (`apps/engine`, `apps/web`, `packages/sdk`, `contracts`)
- [x] Root workspace config + scripts
- [x] Master README (architecture, diagrams, tables)
- [x] This checklist
- [x] Asset generation prompts (`design/ASSETS.md`)
- [x] Approved landing HTML reference (`design/landing.reference.html`)
- [x] Approved dashboard HTML reference (`design/dashboard.reference.html`)
- [x] Env templates for engine, web, contracts
- [x] Engine, SDK, contract, and web stubs with types + interfaces in place

---

## Phase 1 — Engine core  ✅

- [x] X Layer fork simulator (viem eth_call + debug_traceCall at latest block)
- [x] Execute unsigned transaction against the fork
- [x] Capture trace + revert reason
- [x] State-diff extractor (transfers, approvals, net balance deltas)
- [x] Intent parser (structured declared-intent object from free text)
- [x] Unit tests: clean diff, revert capture, intent extraction — all green

> Live-RPC note: fork simulation runs against the RPC in `apps/engine/.env`.
> A node exposing `debug_traceCall` gives full internal-call log capture;
> without it the simulator still returns revert state + decodable logs.

**Commands**
```bash
npm run engine:dev
npm --workspace apps/engine run test
```

---

## Phase 2 — Rule layers  ✅

- [x] `intent-divergence` — diff declared intent against simulated effect
- [x] `approval-risk` — unlimited / policy-sensitive approval flagging
- [x] `drainer / counterparty` — drainer set + registered-recipient screen
- [x] `honeypot` — sell-block + fee-on-transfer signals (sell-sim wiring marked)
- [x] `slippage` — realised-below-declared vs policy ceiling
- [x] Verdict aggregator (rules → ALLOW / WARN / VETO + reasons)
- [x] Unit tests per rule with fixture transactions — 9 passing

> `registries.ts` holds the drainer + registered-recipient lookups. Seed is
> empty by design; load a live threat feed and the caller ledger at boot.

---

## Phase 3 — Contract  ✅ (code) / ⏳ (deploy needs your faucet OKB)

- [x] All-rounder attestation contract (deploy-once design):
      - stores verdict enum (ALLOW/WARN/VETO), not just a hash
      - per-agent verdict history + pagination (on-chain reputation feed)
      - batch attestation for high volume
      - revoke / supersede preserving history (forensics trail)
      - x402 payment reference + bindPayment hook
      - free-form bytes metadata slot (forward-compat, no redeploy ever)
      - multi-attester auth, pausable, two-step ownership transfer
- [x] Events indexed for the dashboard ledger (Attested / Revoked / PaymentBound)
- [x] Hardhat test suite — 11 tests (attest, batch, history, revoke, metadata,
      payment, auth, pause, ownership)
- [ ] Deploy to X Layer testnet (needs faucet OKB in deployer wallet)
- [ ] Capture deployed address + deploy tx hash as proof artifacts

**Deploy commands**
```bash
# 1. fund the deployer: https://web3.okx.com/xlayer/faucet  (claim 0.2 OKB)
# 2. put the deployer key in contracts/.env  (DEPLOYER_PRIVATE_KEY=...)
npm run contracts:compile
npm run contracts:test
npm run contracts:deploy
# 3. copy the printed address into apps/engine/.env  (ATTESTATION_ADDRESS=...)
```

**Commands**
```bash
npm run contracts:compile
npm run contracts:test
npm run contracts:deploy
```

---

## Phase 4 — Server + x402  ✅ (code) / ⏳ (live needs OKX API keys)

- [x] `POST /verdict` wired to the full engine + payment gate
- [x] `POST /approvals` `/payload` `/counterparty` `/forensics` gated (handlers land per-instrument)
- [x] x402 pay-per-call gate — real OKX Facilitator flow:
      402 challenge → decode X-PAYMENT → /verify → /settle (sync) on X Layer
- [x] OKX Facilitator client with OK-ACCESS-SIGN HMAC auth (exact + EIP-3009)
- [x] Pricing → atomic units, PaymentRequirements + 402 challenge builder
- [x] Settlement tx hash bound to the verdict attestation as paymentRef
- [x] Evidence bundle assembled + hashed + returned
- [x] Attestation written on each verdict (live against the deployed contract)
- [x] Unit tests — pricing, requirements, challenge, config gate (13 total green)
- [ ] Set OKX_API_KEY / SECRET / PASSPHRASE + VETO_PAYTO_ADDRESS to enforce payment
- [ ] Redis verdict cache (optional)

**Run**
```bash
npm run engine:dev
# health:  GET  http://localhost:8787/health
# verdict: POST http://localhost:8787/verdict  (402 until X-PAYMENT provided)
```

> Payment enforces only when the four OKX vars are set. Without them the
> engine runs open (dev mode) so you can test the verdict pipeline first,
> then flip payment on by filling the keys. Settlement is real USDT on
> X Layer mainnet (eip155:196) via the OKX Facilitator.

---

## Phase 5 — SDK  ✅

- [x] `guard(signer, opts)` wrapper (ethers v6 compatible, Proxy-based)
- [x] `check(tx, from, opts)` one-shot verdict without wrapping a signer
- [x] Auto-route every outgoing tx through `/verdict`
- [x] Refuse to sign on VETO (`VetoRefused`); WARN signs, or refuses under `strictWarn`
- [x] `onVerdict` callback hook (fires on every ruling)
- [x] x402 payment: 402 → `paySettle` hook → retry once (`VetoPaymentRequired` if unpaid)
- [x] Unit tests — guard, check, VETO/WARN/ALLOW, payment retry (7 green)
- [x] Clean build (`packages/sdk/dist`: index.js + index.d.ts, tests excluded)
- [x] README with integration examples

**Build + test**
```bash
npm run sdk:build
npm --workspace packages/sdk run test
```

**Commands**
```bash
npm run sdk:build
```

---

## Phase 6 — Next.js UI

### 6A — Landing  DONE
- [x] Full port of the approved landing into Next.js (all 8 sections)
- [x] Hero full-bleed figure (public/hero-figure.png) + floating verdict cards
- [x] Hero parallax (scroll + mouse), scroll-driven horizontal capabilities deck
- [x] Reveal-on-scroll, Lenis smooth scroll, reduced-motion respected
- [x] Full mobile pass — cards stack, deck goes vertical on touch, fluid type
- [x] Builds clean (next build), all routes generated

### 6B — Dashboard  NEXT
- [ ] Port approved dashboard (all modules, one palette)
- [ ] Charts (verdict trends, latency, distribution, risk timeline)
- [ ] Mobile pass (sidebar drawer)

**Commands**
```bash
npm run web:dev
npm run web:build
```

---

## Phase 7 — Integration

- [ ] Dashboard reads live verdict feed from engine
- [ ] Intent-vs-effect panel bound to real verdicts
- [ ] Attestation ledger reads on-chain events
- [ ] x402 billing panel reads real usage

---

## Phase 8 — Deploy

- [ ] Web → Vercel
- [ ] Engine → Railway
- [ ] Contract live on X Layer testnet with public address
- [ ] End-to-end smoke test through the deployed stack

---

## Phase 9 — Listing (post-checklist)

- [ ] Register ASP on OKX.AI (A2MCP)
- [ ] Submit for listing review **by July 14–15** (not the deadline)
- [ ] Confirm listing goes live

## Phase 10 — Demo / X post

- [ ] 90-second demo video (paste malicious tx → VETO → attestation hash)
- [ ] X thread, tag `@OKX` / `@XLayerOfficial`, hashtag `#okxai`
- [ ] Public "VETO a live malicious tx" post
VETO_FILE_6_END_9f3a

echo ""
echo "Done. Phase 6A files written."
echo "Install lenis:  npm install"
echo "Run:            npm run web:dev    then open http://localhost:3000"
