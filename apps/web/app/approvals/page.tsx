"use client";

import { useState } from "react";
import Link from "next/link";
import { scanApprovals, type ApprovalsReport } from "../../lib/engine";
import "../../styles/dashboard.css";
import "../../styles/console.css";

export default function Approvals() {
  const [wallet, setWallet] = useState("");
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState<ApprovalsReport | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setLoading(true); setError(null); setReport(null);
    try { setReport(await scanApprovals(wallet)); }
    catch (e) { setError(e instanceof Error ? e.message : "Scan failed"); }
    finally { setLoading(false); }
  }

  return (
    <div className="console-shell">
      <div className="console-nav">
        <Link className="wm" href="/">VETO<span>.</span></Link>
        <Link className="back" href="/dashboard">Console →</Link>
      </div>

      <div className="console-wrap">
        <div className="console-head">
          <div className="kick">Approval hygiene</div>
          <h1>Which allowances can drain this wallet?</h1>
          <p>
            VETO reconstructs every approval this wallet ever granted, checks which are
            still live on X Layer, and scores each by drain exposure. Every dangerous one
            comes back with a ready-to-sign revocation transaction.
          </p>
        </div>

        <div className="card">
          <h2>Wallet</h2>
          <div className="sub">The agent or treasury wallet to audit.</div>
          <div className="field">
            <label>Address</label>
            <input className="mono-in" value={wallet} onChange={(e) => setWallet(e.target.value)} placeholder="0x…" />
          </div>
          <button className="run-btn" onClick={run} disabled={loading || !wallet}>
            {loading ? <span className="spin" /> : null}
            {loading ? "Auditing on-chain…" : "Audit approvals"}
          </button>
        </div>

        <div className="card">
          <h2>Exposure</h2>
          <div className="sub">Live allowances, ranked by drain risk.</div>

          {error && <div className="err">{error}</div>}
          {!error && !report && (
            <div className="result-empty">
              Enter a wallet to see every live allowance and what each one could take.
            </div>
          )}

          {report && (
            <>
              <div className={`verdict-banner ${report.critical > 0 ? "VETO" : report.atRisk > 0 ? "WARN" : "ALLOW"}`}>
                <div className="verdict-ring">{report.exposureScore}</div>
                <div className="vtext">
                  <b>
                    {report.critical > 0 ? "Revoke immediately." : report.atRisk > 0 ? "Review these." : "Nothing exposed."}
                  </b>
                  <span>
                    {report.live} live · {report.critical} critical · {report.scanned} approvals scanned
                  </span>
                </div>
              </div>

              {report.findings.length === 0 && (
                <div className="result-empty">No live allowances. This wallet has nothing exposed.</div>
              )}

              {report.findings.slice(0, 8).map((f) => (
                <div key={f.token + f.spender} style={{ borderTop: "1px solid rgba(20,19,17,.08)", padding: "14px 0" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
                    <span style={{ fontWeight: 600, fontSize: 14 }}>
                      {f.symbol}{" "}
                      <span style={{ color: "var(--ink-3)", fontFamily: "'IBM Plex Mono',monospace", fontSize: 11.5 }}>
                        → {f.spender.slice(0, 10)}…
                      </span>
                    </span>
                    <span className={`chip ${f.risk.toLowerCase()}`}>{f.unlimited ? "UNLIMITED" : f.risk}</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: "var(--ink-2)", marginTop: 6, lineHeight: 1.5 }}>{f.reason}</div>
                </div>
              ))}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
