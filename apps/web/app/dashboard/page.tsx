"use client";

import { useLiveData } from "./live";
import "../../styles/dashboard.css";

const NAV = [
  { label: "Request Verdict", on: false, href: "/console", ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>
  ) },
  { label: "Verdict Overview", on: true, href: "/dashboard", ct: null, icon: (
    <svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="9" rx="1.5" /><rect x="14" y="3" width="7" height="5" rx="1.5" /><rect x="14" y="12" width="7" height="9" rx="1.5" /><rect x="3" y="16" width="7" height="5" rx="1.5" /></svg>
  ) },
  { label: "Approval Hygiene", on: false, href: "/approvals", ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z" /></svg>
  ) },
  { label: "Payload Screening", on: false, href: "/payload", ct: null, icon: (
    <svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2" /><path d="M4 10h16" /></svg>
  ) },
  { label: "Counterparty Check", on: false, href: "/counterparty", ct: null, icon: (
    <svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4" /><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7" /></svg>
  ) },
  { label: "Forensics", on: false, href: "/forensics", ct: null, icon: (
    <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>
  ) },
  { label: "Evidence", on: false, href: "#", ct: null, icon: (
    <svg viewBox="0 0 24 24"><path d="M4 6h16v12H4zM8 10h8M8 14h5" /></svg>
  ) },
  { label: "Attestation", on: false, href: "#", ct: null, icon: (
    <svg viewBox="0 0 24 24"><rect x="5" y="4" width="14" height="16" rx="2" /><path d="M9 9h6M9 13h6M9 17h4" /></svg>
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
        revenue: stats.revenueUsdt.toFixed(2),
        refused: `${stats.refusedCount} signature${stats.refusedCount === 1 ? "" : "s"} refused`,
        latency: `${(stats.avgLatency / 1000).toFixed(2)}s median`,
      }
    : {
        total: "—",
        allow: "—",
        veto: "—",
        revenue: "0.00",
        refused: "awaiting engine",
        latency: "awaiting engine",
      };

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
                {m.latency}
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
                effect matched intent
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
                {m.refused}
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
                {m.revenue}<span style={{ fontSize: 17, color: "var(--ink-3)" }}> USDT</span>
              </div>
              <div className="d">
                0.15 USDT per ruling
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
