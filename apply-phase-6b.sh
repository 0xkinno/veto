#!/usr/bin/env bash
# VETO — Phase 6B apply script (Next.js dashboard port)
# Run from the root of your veto folder:  bash apply-phase-6b.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 6B files into $(pwd) ..."
mkdir -p apps/web/app/dashboard apps/web/styles

# ---------- apps/web/app/dashboard/page.tsx ----------
cat > apps/web/app/dashboard/page.tsx << 'VETO_FILE_1_END_9f3a'
import "../../styles/dashboard.css";

export const metadata = {
  title: "VETO — Verdict Console",
  description: "Every ruling this engine has issued — simulated, diffed, and attested on X Layer.",
};

const NAV = [
  { label: "Overview", on: true, ct: null, icon: (
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
          <a className={`nitem${n.on ? " on" : ""}`} href="#" key={n.label}>
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
              <span className="pulse"></span>Engine live · #9,412,391
            </div>
            <div className="icon-btn">
              <svg viewBox="0 0 24 24"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0" /></svg>
            </div>
            <button className="btn dark">
              <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>
              Request verdict
            </button>
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
              <div className="v">1,284</div>
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
              <div className="v">1,243</div>
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
              <div className="v" style={{ color: "var(--crimson)" }}>41</div>
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
                <div className="vrow"><span className="chip veto">VETO</span><div className="vmain"><b>Swap 50 USDT → OKB</b><span>agent #4127 · 1.8s</span></div></div>
                <div className="vrow"><span className="chip allow">ALLOW</span><div className="vmain"><b>Escrow release · #8812</b><span>agent #2210 · 1.1s</span></div></div>
                <div className="vrow"><span className="chip warn">WARN</span><div className="vmain"><b>Swap 800 USDT → WOKB</b><span>agent #4616 · 1.6s</span></div></div>
                <div className="vrow"><span className="chip allow">ALLOW</span><div className="vmain"><b>Payroll batch · 12 tx</b><span>treasury #77 · 2.2s</span></div></div>
                <div className="vrow"><span className="chip veto">VETO</span><div className="vmain"><b>Buy 0x7f9…c41</b><span>agent #3808 · 1.7s</span></div></div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
VETO_FILE_1_END_9f3a

# ---------- apps/web/styles/dashboard.css ----------
cat > apps/web/styles/dashboard.css << 'VETO_FILE_2_END_9f3a'

:root{
  --ivory:#F4F1E9;--stone:#ECE8DD;--card:#FFFFFF;
  --ink:#141311;--ink-2:#5D584C;--ink-3:#948E7E;
  --line:rgba(20,19,17,.10);--line-soft:rgba(20,19,17,.06);
  --emerald:#2E7A57;--emerald-bg:rgba(46,122,87,.10);
  --amber:#9A6E1E;--amber-bg:rgba(154,110,30,.10);
  --crimson:#96302E;--crimson-bg:rgba(150,48,46,.09);
  --slate:#4E5F78;--slate-bg:rgba(78,95,120,.10);
  --ease:cubic-bezier(.22,.61,.21,1);--r:16px;
}
*{margin:0;padding:0;box-sizing:border-box}
body{
  background:
    linear-gradient(180deg,rgba(120,140,120,.14),transparent 22%),
    linear-gradient(0deg,rgba(120,140,110,.16),transparent 20%),
    var(--stone);
  color:var(--ink);font-family:'Inter Tight',-apple-system,sans-serif;font-size:14px;
  -webkit-font-smoothing:antialiased;min-height:100vh;
}
.mono{font-family:'IBM Plex Mono',monospace}
.serif{font-family:'Newsreader',Georgia,serif}

.shell{display:grid;grid-template-columns:238px 1fr;gap:18px;max-width:1360px;margin:0 auto;padding:22px;min-height:100vh}

/* ---------- sidebar card ---------- */
aside{
  background:var(--card);border-radius:20px;border:1px solid var(--line-soft);
  box-shadow:0 4px 24px rgba(30,40,30,.06);
  padding:20px 14px;display:flex;flex-direction:column;gap:3px;
  position:sticky;top:22px;height:calc(100vh - 44px);
}
.brand{display:flex;align-items:center;gap:11px;padding:6px 10px 22px}
.brand-mark{width:34px;height:34px;border-radius:10px;background:var(--ink);color:var(--ivory);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:13px;letter-spacing:.06em}
.brand-mark span{color:#E08585}
.brand-txt b{font-size:14px;font-weight:600;letter-spacing:.02em;display:block}
.brand-txt span{font-size:11px;color:var(--ink-3)}
.nitem{
  display:flex;align-items:center;gap:12px;padding:9.5px 12px;border-radius:10px;
  color:var(--ink-2);text-decoration:none;font-size:13.5px;
  transition:background .22s var(--ease),color .22s;
}
.nitem:hover{background:rgba(20,19,17,.045);color:var(--ink)}
.nitem.on{background:var(--stone);color:var(--ink);font-weight:500}
.nitem svg{width:16px;height:16px;stroke:currentColor;stroke-width:1.6;fill:none;opacity:.8}
.nitem .ct{margin-left:auto;font-size:11px;color:var(--ink-3);background:rgba(20,19,17,.05);padding:1px 7px;border-radius:100px}
.nitem.on .ct{background:var(--card)}
.side-foot{margin-top:auto;padding-top:14px;border-top:1px solid var(--line-soft)}
.profile{display:flex;align-items:center;gap:11px;padding:8px 10px;border-radius:12px;transition:background .2s}
.profile:hover{background:rgba(20,19,17,.04)}
.avatar{width:32px;height:32px;border-radius:50%;background:linear-gradient(140deg,#4E5F78,#2c3542);flex-shrink:0}
.profile .who{font-size:13px;font-weight:500;display:flex;align-items:center;gap:5px}
.profile .role{font-size:11px;color:var(--ink-3)}
.verified{width:13px;height:13px;background:var(--slate);border-radius:50%;display:inline-flex;align-items:center;justify-content:center;color:#fff;font-size:8px}
.signout{margin-top:8px;display:flex;align-items:center;gap:9px;padding:9px 12px;border:1px solid var(--line);border-radius:10px;color:var(--ink-2);font-size:12.5px;cursor:pointer;transition:background .2s}
.signout:hover{background:var(--stone)}

/* ---------- main ---------- */
main{display:flex;flex-direction:column;gap:18px;min-width:0}
.topbar{
  background:var(--card);border-radius:18px;border:1px solid var(--line-soft);
  box-shadow:0 4px 24px rgba(30,40,30,.06);
  display:flex;align-items:center;gap:16px;padding:13px 20px;
}
.search{
  display:flex;align-items:center;gap:10px;flex:1;max-width:420px;
  background:var(--stone);border-radius:10px;padding:9px 14px;color:var(--ink-3);font-size:13px;cursor:text;
}
.search svg{width:15px;height:15px;stroke:currentColor;stroke-width:1.7;fill:none}
.top-right{margin-left:auto;display:flex;align-items:center;gap:14px}
.top-status{display:flex;align-items:center;gap:7px;font-size:12px;color:var(--ink-2)}
.pulse{width:7px;height:7px;border-radius:50%;background:var(--emerald);box-shadow:0 0 0 3px var(--emerald-bg)}
.icon-btn{width:36px;height:36px;border-radius:10px;border:1px solid var(--line);background:var(--card);display:flex;align-items:center;justify-content:center;cursor:pointer;transition:background .2s}
.icon-btn:hover{background:var(--stone)}
.icon-btn svg{width:16px;height:16px;stroke:var(--ink-2);stroke-width:1.6;fill:none}
.btn{
  font-family:inherit;font-size:13px;font-weight:500;padding:10px 18px;border-radius:10px;cursor:pointer;
  transition:transform .2s var(--ease),background .25s;border:1px solid var(--line);background:var(--card);color:var(--ink);
  display:inline-flex;align-items:center;gap:8px;
}
.btn:active{transform:scale(.97)}
.btn.dark{background:var(--slate);color:#fff;border-color:var(--slate)}
.btn.dark:hover{background:#42546b}
.btn svg{width:15px;height:15px;stroke:currentColor;stroke-width:1.8;fill:none}

.workspace{
  background:var(--card);border-radius:20px;border:1px solid var(--line-soft);
  box-shadow:0 4px 24px rgba(30,40,30,.06);padding:26px 28px 30px;
}
.page-head{display:flex;align-items:flex-start;justify-content:space-between;gap:20px;flex-wrap:wrap;margin-bottom:26px}
.page-head h1{font-size:23px;font-weight:600;letter-spacing:-.01em}
.page-head .sub{color:var(--ink-3);font-size:13px;margin-top:5px}
.head-filters{display:flex;gap:10px}
.filter{display:flex;align-items:center;gap:8px;border:1px solid var(--line);border-radius:10px;padding:8px 14px;font-size:12.5px;color:var(--ink-2);cursor:pointer;background:var(--card);transition:background .2s}
.filter:hover{background:var(--stone)}
.filter svg{width:13px;height:13px;stroke:currentColor;stroke-width:1.7;fill:none}

/* metrics */
.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:16px}
.metric{border:1px solid var(--line-soft);border-radius:14px;padding:17px 18px;transition:transform .3s var(--ease),box-shadow .3s var(--ease)}
.metric:hover{transform:translateY(-2px);box-shadow:0 8px 22px rgba(30,40,30,.08)}
.metric .top{display:flex;align-items:center;justify-content:space-between}
.metric .k{font-size:12.5px;color:var(--ink-2);font-weight:500}
.micon{width:30px;height:30px;border-radius:9px;display:flex;align-items:center;justify-content:center}
.micon svg{width:15px;height:15px;stroke-width:1.7;fill:none}
.metric .v{font-size:32px;font-weight:600;letter-spacing:-.02em;margin-top:14px;font-variant-numeric:tabular-nums}
.metric .d{font-size:12px;margin-top:6px;display:flex;align-items:center;gap:6px;color:var(--ink-3)}
.up{color:var(--emerald)}.dn{color:var(--crimson)}

/* chart row */
.charts{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px}
.chart-card{border:1px solid var(--line-soft);border-radius:14px;padding:20px 22px}
.chart-head{display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:6px}
.chart-head h2{font-size:15px;font-weight:600}
.chart-head .sub{font-size:12px;color:var(--ink-3);margin-top:3px}
.chart-body{margin-top:20px}
.linechart{width:100%;height:170px}
.barchart{display:flex;align-items:flex-end;justify-content:space-around;height:170px;gap:20px;padding-top:10px}
.barcol{display:flex;flex-direction:column;align-items:center;gap:10px;flex:1;height:100%;justify-content:flex-end}
.barcol .bar{width:100%;max-width:56px;border-radius:7px 7px 0 0;background:var(--slate);opacity:.85;transition:opacity .25s}
.barcol:hover .bar{opacity:1}
.barcol .lbl{font-size:11px;color:var(--ink-3)}

/* lower row */
.lower{display:grid;grid-template-columns:1fr 1fr 1fr;gap:14px}
.lcard{border:1px solid var(--line-soft);border-radius:14px;padding:20px 22px}
.lcard h2{font-size:14.5px;font-weight:600;margin-bottom:3px}
.lcard .sub{font-size:11.5px;color:var(--ink-3);margin-bottom:18px}
.chip{font-size:10px;font-weight:600;letter-spacing:.12em;padding:3.5px 9px;border-radius:100px;white-space:nowrap}
.chip.allow{color:var(--emerald);background:var(--emerald-bg)}
.chip.warn{color:var(--amber);background:var(--amber-bg)}
.chip.veto{color:var(--crimson);background:var(--crimson-bg)}
/* donut */
.donut-wrap{display:flex;align-items:center;gap:20px}
.legend{display:flex;flex-direction:column;gap:9px;flex:1}
.legend .li{display:flex;align-items:center;gap:9px;font-size:12.5px;color:var(--ink-2)}
.legend .li .sw{width:9px;height:9px;border-radius:2px}
.legend .li b{margin-left:auto;color:var(--ink);font-weight:500;font-variant-numeric:tabular-nums}
/* sev bars */
.sev{display:flex;flex-direction:column;gap:14px}
.sev .row .top{display:flex;justify-content:space-between;font-size:12.5px;margin-bottom:6px}
.sev .row .top b{font-weight:500;font-variant-numeric:tabular-nums}
.track2{height:6px;border-radius:100px;background:rgba(20,19,17,.07);overflow:hidden}
.track2 i{display:block;height:100%;border-radius:100px}
/* verdict list */
.vlist{display:flex;flex-direction:column}
.vrow{display:flex;align-items:center;gap:12px;padding:12px 0;border-bottom:1px solid var(--line-soft)}
.vrow:last-child{border-bottom:none}
.vrow .vmain{flex:1;min-width:0}
.vrow .vmain b{font-size:13px;font-weight:500;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.vrow .vmain span{font-size:11.5px;color:var(--ink-3)}

@media(max-width:1080px){
  .shell{grid-template-columns:1fr}
  aside{position:static;height:auto;flex-direction:row;flex-wrap:wrap;align-items:center}
  .side-foot{display:none}
  .metrics{grid-template-columns:repeat(2,1fr)}
  .charts,.lower{grid-template-columns:1fr}
}

/* ---------- phone polish ---------- */
@media(max-width:640px){
  .shell{padding:14px;gap:14px}
  aside{
    flex-direction:column;align-items:stretch;padding:14px 10px;
    border-radius:16px;gap:2px;
  }
  /* collapse nav to a horizontal scroll strip of the primary items */
  .brand{padding:4px 8px 14px}
  aside{overflow:visible}
  .nitem{padding:10px 12px}
  .nitem .ct{margin-left:auto}
  .workspace{padding:18px 16px 22px;border-radius:16px}
  .topbar{padding:11px 14px;border-radius:14px;flex-wrap:wrap}
  .search{max-width:none;order:3;width:100%}
  .top-right{margin-left:0;width:100%;justify-content:space-between}
  .page-head h1{font-size:20px}
  .head-filters{width:100%}
  .filter{flex:1;justify-content:center}
  .metrics{grid-template-columns:1fr 1fr;gap:10px}
  .metric .v{font-size:26px}
  .charts,.lower{grid-template-columns:1fr;gap:12px}
  .barchart{height:150px}
  .donut-wrap{flex-direction:row}
}

/* very small phones: single-column metrics */
@media(max-width:420px){
  .metrics{grid-template-columns:1fr}
}
VETO_FILE_2_END_9f3a

# ---------- docs/CHECKLIST.md ----------
cat > docs/CHECKLIST.md << 'VETO_FILE_3_END_9f3a'
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

### 6B — Dashboard  DONE
- [x] Full port of the approved dashboard into Next.js (/dashboard)
- [x] Sidebar (9 modules + profile), topbar with live engine status
- [x] Four metric cards (verdicts, allowed, vetoed, x402 revenue)
- [x] Verdict-trends line chart + median-latency bar chart (inline SVG)
- [x] Lower row: distribution donut, risk timeline, recent verdicts list
- [x] Full mobile pass — metrics reflow, charts stack, single-column on phones
- [x] Builds clean, /dashboard route generated

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
VETO_FILE_3_END_9f3a

echo ""
echo "Done. Phase 6B files written."
echo "Run:  npm run web:dev   then open http://localhost:3000/dashboard"
