"use client";

import { useState } from "react";
import Link from "next/link";
import { runForensics, type ForensicsReport } from "../../lib/engine";
import "../../styles/dashboard.css";
import "../../styles/console.css";

export default function Forensics() {
  const [txHash, setTxHash] = useState("");
  const [policy, setPolicy] = useState("standard");
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState<ForensicsReport | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setLoading(true); setError(null); setReport(null);
    try { setReport(await runForensics(txHash, policy)); }
    catch (e) { setError(e instanceof Error ? e.message : "Replay failed"); }
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
          <div className="kick">Post-incident forensics</div>
          <h1>What should have been caught?</h1>
          <p>
            Replay any real X Layer transaction through the live rule pipeline. VETO
            reconstructs the effects it actually produced and reports the verdict it
            would have returned — had anyone thought to ask, before the signature.
          </p>
        </div>

        <div className="card">
          <h2>Transaction</h2>
          <div className="sub">Any historical transaction on X Layer.</div>
          <div className="field">
            <label>Transaction hash</label>
            <input className="mono-in" value={txHash} onChange={(e) => setTxHash(e.target.value)} placeholder="0x…" />
          </div>
          <div className="field">
            <label>Policy profile to judge it against</label>
            <select value={policy} onChange={(e) => setPolicy(e.target.value)}>
              <option value="treasury-strict">treasury-strict</option>
              <option value="standard">standard</option>
              <option value="degen-loose">degen-loose</option>
            </select>
          </div>
          <button className="run-btn" onClick={run} disabled={loading || !txHash}>
            {loading ? <span className="spin" /> : null}
            {loading ? "Replaying on-chain…" : "Replay transaction"}
          </button>
        </div>

        <div className="card">
          <h2>Post-mortem</h2>
          <div className="sub">The ruling this transaction never got.</div>

          {error && <div className="err">{error}</div>}
          {!error && !report && (
            <div className="result-empty">
              Paste a transaction hash to see what VETO would have ruled before it was signed.
            </div>
          )}

          {report && (
            <>
              <div className={`verdict-banner ${report.wouldHaveRuled}`}>
                <div className="verdict-ring">{report.wouldHaveRuled}</div>
                <div className="vtext">
                  <b>
                    {report.wouldHaveRuled === "VETO"
                      ? "Would have been refused."
                      : report.wouldHaveRuled === "WARN"
                      ? "Would have been flagged."
                      : "Would have been cleared."}
                  </b>
                  <span>{report.status} · block #{report.blockNumber.toLocaleString()}</span>
                </div>
              </div>

              <div style={{ fontSize: 14, color: "var(--ink-2)", lineHeight: 1.65, margin: "18px 0" }}>
                {report.postMortem}
              </div>

              {report.reasons.length > 0 && (
                <div className="reasons">
                  {report.reasons.map((r, i) => (
                    <div className="reason" key={i}>{r}</div>
                  ))}
                </div>
              )}

              <div className="result-meta">
                <div className="meta-row"><span className="k">From</span><span className="v">{report.from.slice(0, 12)}…</span></div>
                <div className="meta-row"><span className="k">Judged under</span><span className="v">{report.policy}</span></div>
                <div className="meta-row"><span className="k">Evidence hash</span><span className="v">{report.evidenceHash.slice(0, 20)}…</span></div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
