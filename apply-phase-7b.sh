#!/usr/bin/env bash
# VETO — Phase 7b apply script (console-first routing + dashboard reorder + README)
# Run from the root of your veto folder:  bash apply-phase-7b.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 7b files into $(pwd) ..."
mkdir -p apps/web/app apps/web/app/dashboard

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

# ---------- apps/web/app/dashboard/page.tsx ----------
cat > apps/web/app/dashboard/page.tsx << 'VETO_FILE_2_END_9f3a'
"use client";

import { useLiveData } from "./live";
import "../../styles/dashboard.css";

const NAV = [
  { label: "Request Verdict", on: false, href: "/console", ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>
  ) },
  { label: "Verdict Overview", on: true, ct: null, icon: (
    <svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="9" rx="1.5" /><rect x="14" y="3" width="7" height="5" rx="1.5" /><rect x="14" y="12" width="7" height="9" rx="1.5" /><rect x="3" y="16" width="7" height="5" rx="1.5" /></svg>
  ) },
  { label: "Transaction Queue", on: false, ct: "24", icon: (
    <svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2" /><path d="M4 10h16" /></svg>
  ) },
  { label: "Simulation Engine", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8" /><path d="M12 8v4l3 2" /></svg>
  ) },
  { label: "Intent Analysis", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M12 3v18M5 8l7-5 7 5M5 16l7 5 7-5" /></svg>
  ) },
  { label: "Evidence", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M4 6h16v12H4zM8 10h8M8 14h5" /></svg>
  ) },
  { label: "Policy", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z" /></svg>
  ) },
  { label: "Risk Timeline", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M4 19V5m0 14h16M8 15v-4m4 4V8m4 7v-6" /></svg>
  ) },
  { label: "Attestation", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><rect x="5" y="4" width="14" height="16" rx="2" /><path d="M9 9h6M9 13h6M9 17h4" /></svg>
  ) },
  { label: "Recent Verdicts", on: false, ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M3 12h4l3-8 4 16 3-8h4" /></svg>
  ) },
];

export default function Dashboard() {
  const { stats, verdicts, live } = useLiveData();

  // Live values when the engine has data, otherwise the sample showcase numbers.
  const m = stats
    ? {
        total: stats.total.toLocaleString(),
        allow: stats.allow.toLocaleString(),
        veto: stats.veto.toLocaleString(),
      }
    : { total: "1,284", allow: "1,243", veto: "41" };

  return (
    <div className="shell">
      {/* SIDEBAR */}
      <aside>
        <div className="brand">
          <div className="brand-mark">
            VE<span>.</span>
          </div>
          <div className="brand-txt">
            <b>VETO</b>
            <span>Verdict Console</span>
          </div>
        </div>

        {NAV.map((n) => (
          <a className={`nitem${n.on ? " on" : ""}`} href={n.href ?? "#"} key={n.label}>
            {n.icon}
            {n.label}
            {n.ct && <span className="ct">{n.ct}</span>}
          </a>
        ))}

        <div className="side-foot">
          <div className="profile">
            <div className="avatar"></div>
            <div>
              <div className="who">
                Meridian Treasury <span className="verified">✓</span>
              </div>
              <div className="role">treasury-strict</div>
            </div>
          </div>
          <div className="signout">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
              <path d="M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
            </svg>
            Sign out
          </div>
        </div>
      </aside>

      {/* MAIN */}
      <main>
        <div className="topbar">
          <div className="search">
            <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>
            Search verdicts, agents, evidence…
          </div>
          <div className="top-right">
            <div className="top-status">
              <span className="pulse"></span>{live ? "Engine live · real-time" : "Engine · sample data"}
            </div>
            <div className="icon-btn">
              <svg viewBox="0 0 24 24"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0" /></svg>
            </div>
            <a href="/console" className="btn dark">
              <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>
              Request verdict
            </a>
          </div>
        </div>

        <div className="workspace">
          <div className="page-head">
            <div>
              <h1>Verdict Overview</h1>
              <div className="sub">
                Every ruling this engine has issued — simulated, diffed, and
                attested on X Layer.
              </div>
            </div>
            <div className="head-filters">
              <div className="filter">
                All Policies <svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" /></svg>
              </div>
              <div className="filter">
                Last 7 Days <svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" /></svg>
              </div>
            </div>
          </div>

          {/* METRICS */}
          <div className="metrics">
            <div className="metric">
              <div className="top">
                <span className="k">Total Verdicts</span>
                <span className="micon" style={{ background: "var(--slate-bg)" }}>
                  <svg viewBox="0 0 24 24" stroke="var(--slate)"><path d="M3 12h4l3-8 4 16 3-8h4" /></svg>
                </span>
              </div>
              <div className="v">{m.total}</div>
              <div className="d">
                <span className="up">▲ 12.4%</span> vs prior period
              </div>
            </div>
            <div className="metric">
              <div className="top">
                <span className="k">Allowed</span>
                <span className="micon" style={{ background: "var(--emerald-bg)" }}>
                  <svg viewBox="0 0 24 24" stroke="var(--emerald)"><path d="M20 6 9 17l-5-5" /></svg>
                </span>
              </div>
              <div className="v">{m.allow}</div>
              <div className="d">
                <span className="up">▲ 11.0%</span> effect matched intent
              </div>
            </div>
            <div className="metric">
              <div className="top">
                <span className="k">Vetoed</span>
                <span className="micon" style={{ background: "var(--crimson-bg)" }}>
                  <svg viewBox="0 0 24 24" stroke="var(--crimson)"><circle cx="12" cy="12" r="9" /><path d="M15 9l-6 6M9 9l6 6" /></svg>
                </span>
              </div>
              <div className="v" style={{ color: "var(--crimson)" }}>{m.veto}</div>
              <div className="d">
                <b style={{ color: "var(--ink)" }}>$182,400</b> exposure refused
              </div>
            </div>
            <div className="metric">
              <div className="top">
                <span className="k">x402 Revenue</span>
                <span className="micon" style={{ background: "var(--amber-bg)" }}>
                  <svg viewBox="0 0 24 24" stroke="var(--amber)"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" /></svg>
                </span>
              </div>
              <div className="v">
                318<span style={{ fontSize: 17, color: "var(--ink-3)" }}> USDT</span>
              </div>
              <div className="d">
                <span className="up">▲ 8.1%</span> 0.15–0.50 per ruling
              </div>
            </div>
          </div>

          {/* CHARTS */}
          <div className="charts">
            <div className="chart-card">
              <div className="chart-head">
                <div>
                  <h2>Verdict Trends</h2>
                  <div className="sub">Rulings issued and refused over the last 10 days</div>
                </div>
                <div className="filter">
                  All Verdicts <svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" /></svg>
                </div>
              </div>
              <div className="chart-body">
                <svg className="linechart" viewBox="0 0 520 170" preserveAspectRatio="none">
                  <g stroke="rgba(20,19,17,.06)" strokeWidth="1">
                    <line x1="0" y1="34" x2="520" y2="34" />
                    <line x1="0" y1="85" x2="520" y2="85" />
                    <line x1="0" y1="136" x2="520" y2="136" />
                  </g>
                  <polyline fill="none" stroke="var(--emerald)" strokeWidth="2.5" points="0,120 58,110 116,116 174,96 232,104 290,80 348,90 406,66 464,74 520,58" />
                  <polyline fill="none" stroke="var(--crimson)" strokeWidth="2.5" strokeDasharray="1" points="0,150 58,148 116,152 174,144 232,150 290,140 348,146 406,138 464,142 520,134" />
                  <circle cx="290" cy="80" r="4" fill="var(--emerald)" />
                  <circle cx="290" cy="140" r="4" fill="var(--crimson)" />
                </svg>
                <div style={{ display: "flex", justifyContent: "space-between", marginTop: 12, fontSize: "10.5px", color: "var(--ink-3)" }}>
                  <span>Jul 1</span><span>Jul 3</span><span>Jul 5</span><span>Jul 7</span><span>Jul 9</span><span>Jul 10</span>
                </div>
                <div style={{ display: "flex", gap: 20, marginTop: 14, fontSize: 12 }}>
                  <span style={{ display: "flex", alignItems: "center", gap: 7, color: "var(--ink-2)" }}>
                    <span style={{ width: 9, height: 9, borderRadius: 2, background: "var(--emerald)" }}></span>Allowed
                  </span>
                  <span style={{ display: "flex", alignItems: "center", gap: 7, color: "var(--ink-2)" }}>
                    <span style={{ width: 9, height: 9, borderRadius: 2, background: "var(--crimson)" }}></span>Vetoed
                  </span>
                </div>
              </div>
            </div>
            <div className="chart-card">
              <div className="chart-head">
                <div>
                  <h2>Median Latency</h2>
                  <div className="sub">Verdict resolution time by policy profile</div>
                </div>
                <div className="filter">
                  All Status <svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" /></svg>
                </div>
              </div>
              <div className="chart-body">
                <div className="barchart">
                  <div className="barcol"><div className="bar" style={{ height: "32%" }}></div><span className="lbl">strict</span></div>
                  <div className="barcol"><div className="bar" style={{ height: "52%" }}></div><span className="lbl">standard</span></div>
                  <div className="barcol"><div className="bar" style={{ height: "74%" }}></div><span className="lbl">loose</span></div>
                  <div className="barcol"><div className="bar" style={{ height: "96%" }}></div><span className="lbl">forensic</span></div>
                </div>
              </div>
            </div>
          </div>

          {/* LOWER */}
          <div className="lower">
            <div className="lcard">
              <h2>Verdict Distribution</h2>
              <div className="sub">Current ruling split</div>
              <div className="donut-wrap">
                <svg width="120" height="120" viewBox="0 0 42 42">
                  <circle cx="21" cy="21" r="15.9" fill="none" stroke="var(--stone)" strokeWidth="6" />
                  <circle cx="21" cy="21" r="15.9" fill="none" stroke="var(--emerald)" strokeWidth="6" strokeDasharray="80 20" strokeDashoffset="25" strokeLinecap="round" />
                  <circle cx="21" cy="21" r="15.9" fill="none" stroke="var(--amber)" strokeWidth="6" strokeDasharray="12 88" strokeDashoffset="-55" strokeLinecap="round" />
                  <circle cx="21" cy="21" r="15.9" fill="none" stroke="var(--crimson)" strokeWidth="6" strokeDasharray="8 92" strokeDashoffset="-67" strokeLinecap="round" />
                </svg>
                <div className="legend">
                  <div className="li"><span className="sw" style={{ background: "var(--emerald)" }}></span>Allow <b>1,243</b></div>
                  <div className="li"><span className="sw" style={{ background: "var(--amber)" }}></span>Warn <b>187</b></div>
                  <div className="li"><span className="sw" style={{ background: "var(--crimson)" }}></span>Veto <b>41</b></div>
                </div>
              </div>
            </div>
            <div className="lcard">
              <h2>Risk Timeline</h2>
              <div className="sub">Most refused patterns · 24h</div>
              <div className="sev">
                <div className="row"><div className="top"><span>Drainer approvals</span><b>82</b></div><div className="track2"><i style={{ width: "82%", background: "var(--crimson)" }}></i></div></div>
                <div className="row"><div className="top"><span>Honeypot sell-blocks</span><b>54</b></div><div className="track2"><i style={{ width: "54%", background: "var(--crimson)" }}></i></div></div>
                <div className="row"><div className="top"><span>Slippage breaches</span><b>37</b></div><div className="track2"><i style={{ width: "37%", background: "var(--amber)" }}></i></div></div>
                <div className="row"><div className="top"><span>Intent divergence</span><b>29</b></div><div className="track2"><i style={{ width: "29%", background: "var(--amber)" }}></i></div></div>
                <div className="row"><div className="top"><span>Stale approvals</span><b>18</b></div><div className="track2"><i style={{ width: "18%", background: "var(--slate)" }}></i></div></div>
              </div>
            </div>
            <div className="lcard">
              <h2>Recent Verdicts</h2>
              <div className="sub">Latest rulings, attested on X Layer</div>
              <div className="vlist">
                {(verdicts && verdicts.length > 0
                  ? verdicts.map((v) => ({
                      key: v.id,
                      verdict: v.verdict,
                      title: v.summary,
                      sub: `${v.agent.slice(0, 6)}…${v.agent.slice(-4)} · ${(v.latencyMs / 1000).toFixed(1)}s`,
                    }))
                  : [
                      { key: "s1", verdict: "VETO", title: "Swap 50 USDT → OKB", sub: "agent #4127 · 1.8s" },
                      { key: "s2", verdict: "ALLOW", title: "Escrow release · #8812", sub: "agent #2210 · 1.1s" },
                      { key: "s3", verdict: "WARN", title: "Swap 800 USDT → WOKB", sub: "agent #4616 · 1.6s" },
                      { key: "s4", verdict: "ALLOW", title: "Payroll batch · 12 tx", sub: "treasury #77 · 2.2s" },
                      { key: "s5", verdict: "VETO", title: "Buy 0x7f9…c41", sub: "agent #3808 · 1.7s" },
                    ]
                ).map((r) => (
                  <div className="vrow" key={r.key}>
                    <span className={`chip ${r.verdict.toLowerCase()}`}>{r.verdict}</span>
                    <div className="vmain">
                      <b>{r.title}</b>
                      <span>{r.sub}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
VETO_FILE_2_END_9f3a

# ---------- README.md ----------
cat > README.md << 'VETO_FILE_3_END_9f3a'
# VETO
### The Last Word Before the Chain — Pre-Signature Verification for Autonomous Agents

![Category](https://img.shields.io/badge/Category-Software_Utility-96302E?style=flat-square&labelColor=141311)
![Network](https://img.shields.io/badge/Network-X_Layer_(196)-2E7A57?style=flat-square&labelColor=141311)
![Payments](https://img.shields.io/badge/Payments-x402_USDT-9A6E1E?style=flat-square&labelColor=141311)
![Attestation](https://img.shields.io/badge/Attestation-On_Chain-4E5F78?style=flat-square&labelColor=141311)
![Contract](https://img.shields.io/badge/Contract-Live-2E7A57?style=flat-square&labelColor=141311)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square&labelColor=141311)

> **Every autonomous transaction is signed in the dark. VETO turns the light on — before the signature, not after the loss.**

VETO is a pre-signature verification layer for autonomous agents. An agent sends VETO an unsigned transaction plus its stated intent. VETO forks X Layer at the current block, executes the exact transaction, diffs what the agent *said* it was doing against what the transaction *actually* does, and returns a signed verdict — ALLOW, WARN, or VETO — before anything is signed, sent, or lost.

**Agents propose. VETO disposes.**

---

## Live Links

| Resource | Link |
|---|---|
| **Live Site (Landing + Console)** | `https://REPLACE-with-your-vercel-url.vercel.app` |
| **Live Verdict Console** | `https://REPLACE-with-your-vercel-url.vercel.app/console` |
| **Verdict Dashboard** | `https://REPLACE-with-your-vercel-url.vercel.app/dashboard` |
| **Engine API (Railway)** | `https://REPLACE-with-your-railway-url.up.railway.app` |
| **OKX.AI Listing** | `https://REPLACE-with-your-okx-ai-asp-link` |
| **Attestation Contract (X Layer)** | [`0xDC7cE940E10ef664B78D185d81AC382AA218f7c4`](https://www.oklink.com/xlayer/address/0xDC7cE940E10ef664B78D185d81AC382AA218f7c4) |
| **Deploy Transaction** | [`0x0ddaea64b5aa1b9b30c1dfeabb9a54ae649d2904be3055b78ad50253e9f0a231`](https://www.oklink.com/xlayer/tx/0x0ddaea64b5aa1b9b30c1dfeabb9a54ae649d2904be3055b78ad50253e9f0a231) |
| **Demo Video (90s)** | `https://REPLACE-with-your-youtube-or-x-link` |
| **X / Twitter Post** | `https://REPLACE-with-your-X-post-link` |
| **GitHub** | `https://github.com/0xkinno/veto` |
| **Hackathon** | OKX AI Genesis Hackathon |

> Replace each `REPLACE-...` value after you deploy and post. The contract and deploy transaction are already live on X Layer and verifiable at the links above.

---

## The problem

Every autonomous transaction is signed in the dark.

An agent holds a wallet, receives a task, and signs — without eyes, without doubt, without appeal. Wallet popups and human-facing scanners assume a person is looking. Autonomous agents execute inside a loop where no one is. A single poisoned task payload or one hallucinated address, and the loss is final. The chain does not forgive.

The only moment a mistake can be caught is the moment before the signature. That moment now has a name.

---

## What makes VETO different

VETO is not a browser extension and not a token scanner. Three properties set it apart:

1. **Agent-native.** A verdict is structured JSON, deterministic, signed, delivered inside the agent's execution loop and paid per call in USDT. An extension cannot serve a machine; VETO is built for one.
2. **Intent-versus-effect diffing.** VETO receives the transaction *and* the agent's stated intent, then diffs the declared purpose against the simulated reality. This catches the failure class no scanner sees: the agent that was deceived. A transaction can be safe in isolation and still be wrong.
3. **Verifiable verdicts.** Every ruling ships with a hash-committed evidence bundle and an attestation written to X Layer. VETO never asks to be believed. Any verdict can be independently re-derived.

> Pocket Universe is a seatbelt for humans. VETO is air traffic control for machines.

---

## System architecture

```mermaid
flowchart TD
    A["Agent / Wallet / SDK"] -->|"unsigned tx + intent"| B["VETO Engine (HTTP)"]
    B --> C["x402 Payment Gate"]
    C -->|"payment settled"| D["Intent Parser"]
    D --> E["Fork Simulator (X Layer @ block N)"]
    E --> F["State-Diff Extractor"]
    F --> G["Rule Pipeline"]
    G --> G1["approval-risk"]
    G --> G2["drainer / counterparty"]
    G --> G3["honeypot simulation"]
    G --> G4["slippage"]
    G --> G5["intent-divergence"]
    G1 --> H["Verdict Aggregator"]
    G2 --> H
    G3 --> H
    G4 --> H
    G5 --> H
    H --> I["Evidence Bundle (hash-committed)"]
    I --> J["Attestation Contract (X Layer)"]
    H -->|"ALLOW / WARN / VETO + evidence"| A
    J -->|"tx hash"| A
```

### Request lifecycle, step by step

```
  agent                 engine                    x layer
    |  POST /verdict       |                          |
    | -------------------> |                          |
    |                      |  402 quote (if unpaid)   |
    | <------------------- |                          |
    |  sign USDT payment   |                          |
    | -------------------> |                          |
    |                      |  fork @ latest block --> |
    |                      | <----- state ----------- |
    |                      |  simulate exact tx ----> |
    |                      | <----- trace / diff ---- |
    |                      |  run rule pipeline       |
    |                      |  aggregate verdict       |
    |                      |  write attestation ----> |
    |                      | <----- tx hash --------- |
    |  verdict + evidence  |                          |
    | <------------------- |                          |
```

---

## The verdict engine

One engine, five instruments. Every capability is the same core — **simulate, diff, prove** — pointed at a different decision.

| Endpoint        | Instrument               | What it answers                                            |
| --------------- | ------------------------ | --------------------------------------------------------- |
| `/verdict`      | Pre-signature verdicts   | Is this exact transaction safe to sign, right now?        |
| `/approvals`    | Approval hygiene         | Which live allowances expose this wallet to a drain?      |
| `/payload`      | Task-payload screening   | Is this inbound job trying to inject or drain?            |
| `/counterparty` | Counterparty pre-check   | Can this address or contract be trusted before I engage?  |
| `/forensics`    | Post-incident forensics  | What should have been caught in this historical tx?       |

### Verdict states

| State   | Meaning                                                          | Signer behaviour       |
| ------- | --------------------------------------------------------------- | ---------------------- |
| `ALLOW` | Simulated effect matches declared intent; no rule triggered.    | Sign proceeds.         |
| `WARN`  | Effect matches intent, but a soft threshold was crossed.        | Sign proceeds + flag.  |
| `VETO`  | Undeclared effect, hard rule hit, or intent divergence.         | Signature refused.     |

---

## Repository layout

```
veto/
├── apps/
│   ├── engine/                  # verdict engine (Node + TypeScript, Fastify)
│   │   └── src/
│   │       ├── simulator/       # X Layer fork simulation
│   │       ├── diff/            # state-diff extractor
│   │       ├── intent/          # intent parser
│   │       ├── rules/           # pluggable rule modules
│   │       ├── evidence/        # evidence bundle + hashing
│   │       ├── x402/            # pay-per-call gate
│   │       ├── routes/          # HTTP endpoints
│   │       └── lib/             # shared types + config
│   └── web/                     # Next.js 14 (landing + dashboard)
├── packages/
│   └── sdk/                     # guard(signer) middleware
├── contracts/                   # attestation contract (Solidity + Hardhat)
├── design/                      # hero + hands assets, generation prompts
└── docs/                        # checklist, architecture, phase notes
```

---

## Try it live

The engine is real. You can watch it rule in three ways.

**1. The verdict console (in your browser).** Open `/console`, click a preset — *Clean swap* or *Undeclared approval* — and hit **Request a verdict**. The engine forks X Layer at the current block, simulates the exact transaction, diffs stated intent against real effect, and returns ALLOW / WARN / VETO with the evidence hash and on-chain attestation. No wallet, no payment — a free window into the paid engine.

**2. The API (what agents actually call).** A single POST returns a structured verdict:

```bash
curl -X POST https://YOUR-ENGINE-URL/demo/verdict \
  -H "content-type: application/json" \
  -d '{
    "tx": { "from": "0xAGENT", "to": "0xSPENDER", "data": "0x095ea7b3", "chainId": 196 },
    "intent": { "summary": "Swap 50 USDT for OKB" },
    "policy": "treasury-strict"
  }'
# → { "verdict": "VETO", "reasons": ["intent-divergence: undeclared approval …"],
#     "evidenceHash": "0x…", "attestationTx": "0x…", "blockNumber": … }
```

**3. As paid infrastructure (x402).** The production `/verdict` endpoint sits behind the OKX Agent Payments Protocol. An agent calls it, receives an HTTP 402 quote, settles USDT on X Layer, and gets the ruling — the settlement transaction hash is bound into the verdict's on-chain attestation. Pay-per-ruling, `0.15`–`0.50` USDT.

---

## Consumption paths

Three ways in. The engine is the same; the commitment scales with you.

1. **Marketplace (A2MCP).** An endpoint on OKX.AI. Any agent pays per verdict in USDT via x402. No account, no key. The payment is the auth.
2. **SDK middleware.** `guard(signer)` around any agent signer. Every outgoing transaction routes through VETO; a red verdict refuses to sign. Ten lines to integrate.
3. **Always-on watch.** Register agent wallets; VETO monitors, alerts, and attests continuously.

```ts
import { guard } from "@veto/sdk";

const signer = guard(agentSigner, {
  policy: "treasury-strict",
  onVerdict: (v) => audit.log(v),
});

// a red verdict refuses to sign — by design
await signer.sendTransaction(tx);
// ✗ VETO — undeclared unlimited approval
```

---

## Quick start

Requirements: Node 20+, an X Layer RPC URL, a funded X Layer testnet key for deploying the attestation contract.

```bash
# 1. install every workspace
npm install

# 2. copy env templates and fill in your keys
cp apps/engine/.env.example apps/engine/.env
cp contracts/.env.example contracts/.env
cp apps/web/.env.example apps/web/.env

# 3. compile + deploy the attestation contract to X Layer testnet
npm run contracts:compile
npm run contracts:deploy

# 4. run the engine (http://localhost:8787)
npm run engine:dev

# 5. run the web app (http://localhost:3000)
npm run web:dev
```

---

## Policy profiles

Callers set a risk posture. The same transaction can be ALLOW under one profile and VETO under another.

| Profile           | Approval cap | Slippage ceiling | Recipient rule           |
| ----------------- | ------------ | ---------------- | ------------------------ |
| `treasury-strict` | Denied       | 1.0%             | Registered ledger only   |
| `standard`        | Bounded      | 3.0%             | Denylist screened        |
| `degen-loose`     | Allowed      | 8.0%             | Warnings only            |

---

## Network

- **Chain:** X Layer (chain id `196`)
- **Payments:** x402 pay-per-call, `0.15`–`0.50` USDT per ruling
- **Attestation:** verdict hash + evidence commitment + policy id, written on-chain per verdict
- **Marketplace:** listed on OKX.AI as an Agent Service Provider

---

## Why VETO wins

| Criterion | How VETO delivers |
|---|---|
| **Product completeness** | A live attestation contract on X Layer, a working verdict engine, real x402 payments, a published SDK, and a polished frontend with a live demo console — end to end, not a slide. |
| **Real user value** | Autonomous agents lose funds to deceived signatures no scanner catches. VETO is the only layer that diffs *stated intent* against *simulated effect* and refuses the signature before the loss. |
| **Technical execution** | Fork simulation, five-rule pipeline, hash-committed evidence, on-chain attestation with per-agent history, EIP-3009 x402 settlement via the OKX Facilitator. |
| **Verifiability** | VETO never asks to be believed. Every ruling ships an evidence hash and an attestation transaction anyone can re-derive and check on X Layer. |
| **Originality** | Not a wallet popup, not a token scanner. Air traffic control for machines — pre-signature, agent-native, paid per call. |

---

## Tech stack

| Layer | Technology |
|---|---|
| Engine | Node 20 · TypeScript · Fastify |
| Simulation | viem · X Layer fork (`eth_call` + `debug_traceCall`) |
| Rules | intent-divergence · approval-risk · counterparty · honeypot · slippage |
| Payments | x402 (`exact` + EIP-3009) via OKX Facilitator · USDT on X Layer |
| Contract | Solidity 0.8.24 · Hardhat · X Layer |
| SDK | TypeScript · `guard(signer)` middleware |
| Frontend | Next.js 14 · Lenis · GSAP · Inter Tight / Newsreader / IBM Plex Mono |
| Deploy | Vercel (web) · Railway (engine) |

---

## Status

This repository is the Phase 0 scaffold. Build phases are tracked in [`docs/CHECKLIST.md`](docs/CHECKLIST.md). Each phase is wired and tested against live infrastructure before the next begins.

Built for the OKX AI Genesis Hackathon.
VETO_FILE_3_END_9f3a

echo ""
echo "Done. Phase 7b files written."
echo "Landing Open console + Request a verdict now route to /console."
echo "Dashboard sidebar: Request Verdict (→/console) first, Verdict Overview second."
echo "README updated with badges + live links (edit the REPLACE-... values after deploy)."
echo "Run:  npm run web:dev"
