"use client";

import { useState } from "react";
import Link from "next/link";
import { runDemoVerdict, type VerdictResponse } from "../../lib/engine";
import "../../styles/dashboard.css"; // for palette tokens
import "../../styles/console.css";

const PRESETS = [
  {
    label: "Clean swap (ALLOW)",
    from: "0x1111111111111111111111111111111111111111",
    to: "0x2222222222222222222222222222222222222222",
    data: "0x",
    summary: "Swap 50 USDT for OKB to settle task #4412",
    policy: "standard" as const,
  },
  {
    label: "Undeclared approval (VETO)",
    from: "0x1111111111111111111111111111111111111111",
    to: "0x7f9000000000000000000000000000000000dc41",
    data: "0x095ea7b3",
    summary: "Swap 50 USDT for OKB",
    policy: "treasury-strict" as const,
  },
];

export default function Console() {
  const [from, setFrom] = useState(PRESETS[0].from);
  const [to, setTo] = useState(PRESETS[0].to);
  const [data, setData] = useState("0x");
  const [value, setValue] = useState("");
  const [summary, setSummary] = useState(PRESETS[0].summary);
  const [policy, setPolicy] = useState<
    "treasury-strict" | "standard" | "degen-loose"
  >("standard");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<VerdictResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  function loadPreset(p: (typeof PRESETS)[number]) {
    setFrom(p.from);
    setTo(p.to);
    setData(p.data);
    setValue("");
    setSummary(p.summary);
    setPolicy(p.policy);
    setResult(null);
    setError(null);
  }

  async function run() {
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const res = await runDemoVerdict({ from, to, data, value, summary, policy });
      setResult(res);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Verdict failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="console-shell">
      <div className="console-nav">
        <Link className="wm" href="/">
          VETO<span>.</span>
        </Link>
        <Link className="back" href="/dashboard">
          Open console →
        </Link>
      </div>

      <div className="console-wrap">
        <div className="console-head">
          <div className="kick">Live verdict</div>
          <h1>Submit a transaction. Get a real ruling.</h1>
          <p>
            The engine forks X Layer at the current block, executes the exact
            transaction, diffs stated intent against real effect, and returns a
            signed verdict — ALLOW, WARN, or VETO. This console calls the live
            engine.
          </p>
        </div>

        {/* INPUT */}
        <div className="card">
          <h2>Transaction</h2>
          <div className="sub">Paste an unsigned transaction and its stated intent.</div>

          <div className="presets">
            {PRESETS.map((p) => (
              <button className="preset" key={p.label} onClick={() => loadPreset(p)}>
                {p.label}
              </button>
            ))}
          </div>

          <div className="field">
            <label>Stated intent</label>
            <input
              value={summary}
              onChange={(e) => setSummary(e.target.value)}
              placeholder="e.g. Swap 50 USDT for OKB"
            />
          </div>
          <div className="row2">
            <div className="field">
              <label>From (agent)</label>
              <input
                className="mono-in"
                value={from}
                onChange={(e) => setFrom(e.target.value)}
                placeholder="0x…"
              />
            </div>
            <div className="field">
              <label>To</label>
              <input
                className="mono-in"
                value={to}
                onChange={(e) => setTo(e.target.value)}
                placeholder="0x…"
              />
            </div>
          </div>
          <div className="field">
            <label>Calldata</label>
            <textarea value={data} onChange={(e) => setData(e.target.value)} placeholder="0x…" />
          </div>
          <div className="row2">
            <div className="field">
              <label>Value (wei, optional)</label>
              <input
                className="mono-in"
                value={value}
                onChange={(e) => setValue(e.target.value)}
                placeholder="0"
              />
            </div>
            <div className="field">
              <label>Policy profile</label>
              <select value={policy} onChange={(e) => setPolicy(e.target.value as typeof policy)}>
                <option value="treasury-strict">treasury-strict</option>
                <option value="standard">standard</option>
                <option value="degen-loose">degen-loose</option>
              </select>
            </div>
          </div>

          <button className="run-btn" onClick={run} disabled={loading}>
            {loading ? <span className="spin" /> : null}
            {loading ? "Rendering verdict…" : "Request verdict"}
          </button>
        </div>

        {/* RESULT */}
        <div className="card">
          <h2>Verdict</h2>
          <div className="sub">The engine&rsquo;s ruling, evidence, and attestation.</div>

          {error && <div className="err">{error}</div>}

          {!error && !result && (
            <div className="result-empty">
              No ruling yet. Load a preset or enter a transaction, then request a
              verdict to see the engine decide in real time.
            </div>
          )}

          {result && (
            <>
              <div className={`verdict-banner ${result.verdict}`}>
                <div className="verdict-ring">{result.verdict}</div>
                <div className="vtext">
                  <b>
                    {result.verdict === "ALLOW"
                      ? "Cleared to sign."
                      : result.verdict === "WARN"
                      ? "Signed with caution."
                      : "Signature refused."}
                  </b>
                  <span>
                    {result.reasons.length
                      ? `${result.reasons.length} finding${
                          result.reasons.length > 1 ? "s" : ""
                        }`
                      : "Effect matched intent · no rule triggered"}
                  </span>
                </div>
              </div>

              {result.reasons.length > 0 && (
                <div className="reasons">
                  {result.reasons.map((r, i) => (
                    <div className="reason" key={i}>
                      {r}
                    </div>
                  ))}
                </div>
              )}

              <div className="result-meta">
                <div className="meta-row">
                  <span className="k">Policy</span>
                  <span className="v">{result.policy}</span>
                </div>
                <div className="meta-row">
                  <span className="k">Simulated at block</span>
                  <span className="v">#{result.blockNumber.toLocaleString()}</span>
                </div>
                <div className="meta-row">
                  <span className="k">Latency</span>
                  <span className="v">{(result.latencyMs / 1000).toFixed(2)}s</span>
                </div>
                <div className="meta-row">
                  <span className="k">Evidence hash</span>
                  <span className="v">{result.evidenceHash}</span>
                </div>
                {result.attestationTx && (
                  <div className="meta-row">
                    <span className="k">Attested on X Layer</span>
                    <span className="v">
                      <a
                        href={`https://www.oklink.com/xlayer/tx/${result.attestationTx}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {result.attestationTx.slice(0, 10)}…{result.attestationTx.slice(-6)}
                      </a>
                    </span>
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
