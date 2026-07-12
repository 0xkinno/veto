"use client";

import { useState } from "react";
import Link from "next/link";
import { checkCounterparty, type CounterpartyReport } from "../../lib/engine";
import "../../styles/dashboard.css";
import "../../styles/console.css";

const GRADE_CLASS: Record<string, string> = {
  TRUSTED: "ALLOW", NEUTRAL: "WARN", CAUTION: "WARN", AVOID: "VETO",
};

export default function Counterparty() {
  const [address, setAddress] = useState("");
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState<CounterpartyReport | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setLoading(true); setError(null); setReport(null);
    try { setReport(await checkCounterparty(address)); }
    catch (e) { setError(e instanceof Error ? e.message : "Check failed"); }
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
          <div className="kick">Counterparty pre-check</div>
          <h1>Know who you are dealing with, first.</h1>
          <p>
            An evidence-graded ruling on any address or contract before an agent engages.
            Bytecode, code size, balance, history, drainer match — every signal read live
            from X Layer, every claim independently checkable.
          </p>
        </div>

        <div className="card">
          <h2>Address</h2>
          <div className="sub">A wallet or contract an agent is about to trust.</div>
          <div className="field">
            <label>Address</label>
            <input className="mono-in" value={address} onChange={(e) => setAddress(e.target.value)} placeholder="0x…" />
          </div>
          <button className="run-btn" onClick={run} disabled={loading || !address}>
            {loading ? <span className="spin" /> : null}
            {loading ? "Reading X Layer…" : "Check counterparty"}
          </button>
        </div>

        <div className="card">
          <h2>Grade</h2>
          <div className="sub">Trust, with the evidence behind it.</div>

          {error && <div className="err">{error}</div>}
          {!error && !report && (
            <div className="result-empty">Enter an address to grade it against live on-chain signals.</div>
          )}

          {report && (
            <>
              <div className={`verdict-banner ${GRADE_CLASS[report.grade]}`}>
                <div className="verdict-ring">{report.trustScore}</div>
                <div className="vtext">
                  <b>{report.grade}</b>
                  <span>{report.summary}</span>
                </div>
              </div>

              <div className="reasons">
                {report.signals.map((s, i) => (
                  <div className="reason" key={i}>
                    <b style={{ color: "var(--ink)" }}>{s.name}</b> = {s.value}
                    <span style={{ color: s.weight < 0 ? "var(--crimson)" : "var(--emerald)", marginLeft: 6 }}>
                      ({s.weight >= 0 ? "+" : ""}{s.weight})
                    </span>
                    <br />
                    {s.note}
                  </div>
                ))}
              </div>

              <div className="result-meta">
                <div className="meta-row"><span className="k">Type</span><span className="v">{report.type}</span></div>
                <div className="meta-row"><span className="k">Bytecode</span><span className="v">{report.onChain.codeSizeBytes} bytes</span></div>
                <div className="meta-row"><span className="k">Outgoing txs</span><span className="v">{report.onChain.outgoingTxCount}</span></div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
