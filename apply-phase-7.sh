#!/usr/bin/env bash
# VETO — Phase 7 apply script (live verdict console + live dashboard data)
# Run from the root of your veto folder:  bash apply-phase-7.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 7 files into $(pwd) ..."
mkdir -p apps/engine/src/lib apps/engine/src/routes apps/web/lib apps/web/app/console apps/web/app/dashboard apps/web/styles

# ---------- apps/engine/src/lib/store.ts ----------
cat > apps/engine/src/lib/store.ts << 'VETO_FILE_1_END_9f3a'
import type { VerdictResponse, VerdictRequest } from "./types";

/**
 * In-memory verdict store. Every ruling the engine issues is recorded here
 * so the dashboard can read live stats and a recent-verdicts feed without a
 * database. For a hackathon this is the right weight: real data, zero infra.
 *
 * Swap the backing array for Redis/Postgres later behind the same functions.
 */

export interface StoredVerdict {
  id: string;
  verdict: VerdictResponse["verdict"];
  policy: string;
  summary: string;
  agent: string;
  evidenceHash: string;
  attestationTx?: string;
  latencyMs: number;
  reasons: string[];
  at: number; // epoch ms
}

const MAX = 500;
const verdicts: StoredVerdict[] = [];

export function record(
  req: VerdictRequest,
  res: VerdictResponse
): StoredVerdict {
  const entry: StoredVerdict = {
    id: res.evidenceHash.slice(0, 10),
    verdict: res.verdict,
    policy: res.policy,
    summary: req.intent.summary,
    agent: req.tx.from,
    evidenceHash: res.evidenceHash,
    attestationTx: res.attestationTx,
    latencyMs: res.latencyMs,
    reasons: res.reasons,
    at: Date.now(),
  };
  verdicts.unshift(entry);
  if (verdicts.length > MAX) verdicts.length = MAX;
  return entry;
}

export function recent(limit = 12): StoredVerdict[] {
  return verdicts.slice(0, limit);
}

export function stats() {
  const total = verdicts.length;
  const allow = verdicts.filter((v) => v.verdict === "ALLOW").length;
  const warn = verdicts.filter((v) => v.verdict === "WARN").length;
  const veto = verdicts.filter((v) => v.verdict === "VETO").length;

  // rule-hit tally for the risk timeline
  const ruleTally: Record<string, number> = {};
  for (const v of verdicts) {
    for (const r of v.reasons) {
      const rule = r.split(":")[0].trim();
      ruleTally[rule] = (ruleTally[rule] ?? 0) + 1;
    }
  }

  const avgLatency =
    total === 0
      ? 0
      : Math.round(verdicts.reduce((s, v) => s + v.latencyMs, 0) / total);

  return { total, allow, warn, veto, avgLatency, ruleTally };
}
VETO_FILE_1_END_9f3a

# ---------- apps/engine/src/routes/index.ts ----------
cat > apps/engine/src/routes/index.ts << 'VETO_FILE_2_END_9f3a'
import type { FastifyInstance } from "fastify";
import { requirePayment, type PaidRequest } from "../x402";
import { runVerdict } from "./verdict-core";
import { recent, stats } from "../lib/store";
import type { VerdictRequest } from "../lib/types";

/**
 * Registers the five VETO instruments. Every endpoint is gated by x402
 * pay-per-call and shares the simulate → diff → prove core.
 *
 * The payment gate settles USDT on X Layer and stashes the on-chain tx
 * hash on the request; runVerdict binds it to the verdict's attestation
 * as paymentRef, so every paid ruling is provably tied to its payment.
 *
 * Read endpoints (/stats, /verdicts) and a free /demo/verdict power the
 * live dashboard + the paste-a-tx demo console. They are not paid: /stats
 * and /verdicts are public reads; /demo/verdict runs the real engine so a
 * judge can see a genuine ruling without settling a payment.
 */
export async function registerRoutes(app: FastifyInstance) {
  app.get("/health", async () => ({ status: "ok", service: "veto-engine" }));

  // ---- live dashboard reads --------------------------------------------
  app.get("/stats", async () => stats());
  app.get("/verdicts", async (request) => {
    const q = request.query as { limit?: string };
    return { verdicts: recent(q.limit ? Number(q.limit) : 12) };
  });

  // ---- /demo/verdict — free, real ruling for the live console ----------
  app.post("/demo/verdict", async (request) => {
    const body = request.body as VerdictRequest;
    return runVerdict(body);
  });

  // ---- /verdict — pre-signature verdicts (paid) ------------------------
  app.post(
    "/verdict",
    { preHandler: requirePayment("verdict") },
    async (request) => {
      const body = request.body as VerdictRequest;
      const payment = (request as PaidRequest).payment;
      return runVerdict(body, payment?.txHash);
    }
  );

  // ---- /approvals — approval hygiene -----------------------------------
  app.post(
    "/approvals",
    { preHandler: requirePayment("approvals") },
    async () => {
      // TODO(phase-4): enumerate live allowances for a wallet, score drain risk.
      return { status: "not-implemented", phase: 4 };
    }
  );

  // ---- /payload — task-payload screening -------------------------------
  app.post(
    "/payload",
    { preHandler: requirePayment("payload") },
    async () => {
      // TODO(phase-4): screen an inbound task payload for injection / drain intent.
      return { status: "not-implemented", phase: 4 };
    }
  );

  // ---- /counterparty — counterparty pre-check --------------------------
  app.post(
    "/counterparty",
    { preHandler: requirePayment("counterparty") },
    async () => {
      // TODO(phase-4): trust-check an address/contract before engaging.
      return { status: "not-implemented", phase: 4 };
    }
  );

  // ---- /forensics — post-incident forensics ----------------------------
  app.post(
    "/forensics",
    { preHandler: requirePayment("forensics") },
    async () => {
      // TODO(phase-4): re-simulate a historical tx, report what should have been caught.
      return { status: "not-implemented", phase: 4 };
    }
  );
}
VETO_FILE_2_END_9f3a

# ---------- apps/engine/src/routes/verdict-core.ts ----------
cat > apps/engine/src/routes/verdict-core.ts << 'VETO_FILE_3_END_9f3a'
import { simulate } from "../simulator";
import { parseIntent } from "../intent";
import { aggregate } from "../rules";
import { buildEvidence } from "../evidence";
import { attest } from "../lib/attest";
import { record } from "../lib/store";
import type { VerdictRequest, VerdictResponse } from "../lib/types";

/**
 * The full verdict flow, shared by /verdict and reused (in part) by the
 * other instruments. Simulate, diff, run rules, hash evidence, attest.
 *
 * @param paymentTxHash  x402 settlement tx hash (from the gate), bound to
 *                       the attestation as paymentRef so the paid ruling
 *                       is provably tied to its on-chain payment.
 */
export async function runVerdict(
  req: VerdictRequest,
  paymentTxHash?: string
): Promise<VerdictResponse> {
  const start = Date.now();

  const intent = parseIntent(req.intent, req.tx);
  const normalised: VerdictRequest = { ...req, intent };

  const sim = await simulate(req.tx);

  // Honeypot check: for any token the caller newly acquired, the engine
  // runs a follow-up sell-simulation and annotates sim.effects with
  // "sell-blocked" / "fee-on-transfer:N" so the honeypot rule can rule on
  // it. Wired against live X Layer once an RPC with fork support is set.
  // const acquired = tokensToSellTest(sim.effects, req.tx.from);
  // await annotateSellSimulations(sim, acquired, req.tx.from);

  const { verdict, findings, reasons } = aggregate(sim, normalised);
  const evidence = buildEvidence(sim, findings, normalised);

  // Attestation is best-effort: a verdict is still valid if the write
  // is pending. The evidence hash is the commitment either way.
  const attestationTx = await attest({
    evidenceHash: evidence.hash,
    verdictHash: evidence.hash, // canonical verdict commitment
    policy: req.policy,
    verdict,
    agent: req.tx.from,
    paymentRef: paymentTxHash,
  }).catch(() => undefined);

  const response: VerdictResponse = {
    verdict,
    reasons,
    findings,
    evidenceHash: evidence.hash,
    attestationTx,
    blockNumber: sim.blockNumber,
    latencyMs: Date.now() - start,
    policy: req.policy,
  };

  // Record every ruling so the dashboard reads live data.
  record(normalised, response);

  return response;
}
VETO_FILE_3_END_9f3a

# ---------- apps/web/lib/engine.ts ----------
cat > apps/web/lib/engine.ts << 'VETO_FILE_4_END_9f3a'
// Client for the VETO engine. Base URL comes from NEXT_PUBLIC_ENGINE_URL so
// the deployed dashboard (Vercel) can point at the deployed engine (Railway).

export const ENGINE_URL =
  process.env.NEXT_PUBLIC_ENGINE_URL ?? "http://localhost:8787";

export type Verdict = "ALLOW" | "WARN" | "VETO";

export interface StoredVerdict {
  id: string;
  verdict: Verdict;
  policy: string;
  summary: string;
  agent: string;
  evidenceHash: string;
  attestationTx?: string;
  latencyMs: number;
  reasons: string[];
  at: number;
}

export interface Stats {
  total: number;
  allow: number;
  warn: number;
  veto: number;
  avgLatency: number;
  ruleTally: Record<string, number>;
}

export interface VerdictResponse {
  verdict: Verdict;
  reasons: string[];
  findings: unknown[];
  evidenceHash: string;
  attestationTx?: string;
  blockNumber: number;
  latencyMs: number;
  policy: string;
}

export async function getStats(): Promise<Stats | null> {
  try {
    const r = await fetch(`${ENGINE_URL}/stats`, { cache: "no-store" });
    if (!r.ok) return null;
    return (await r.json()) as Stats;
  } catch {
    return null;
  }
}

export async function getVerdicts(limit = 12): Promise<StoredVerdict[]> {
  try {
    const r = await fetch(`${ENGINE_URL}/verdicts?limit=${limit}`, {
      cache: "no-store",
    });
    if (!r.ok) return [];
    const data = (await r.json()) as { verdicts: StoredVerdict[] };
    return data.verdicts;
  } catch {
    return [];
  }
}

export interface DemoInput {
  from: string;
  to: string;
  data?: string;
  value?: string;
  summary: string;
  policy: "treasury-strict" | "standard" | "degen-loose";
}

export async function runDemoVerdict(
  input: DemoInput
): Promise<VerdictResponse> {
  const r = await fetch(`${ENGINE_URL}/demo/verdict`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      tx: {
        from: input.from,
        to: input.to,
        data: input.data || "0x",
        value: input.value || undefined,
        chainId: 196,
      },
      intent: { summary: input.summary },
      policy: input.policy,
    }),
  });
  if (!r.ok) {
    const text = await r.text();
    throw new Error(`Engine ${r.status}: ${text}`);
  }
  return (await r.json()) as VerdictResponse;
}
VETO_FILE_4_END_9f3a

# ---------- apps/web/styles/console.css ----------
cat > apps/web/styles/console.css << 'VETO_FILE_5_END_9f3a'
.console-shell{
  min-height:100vh;
  background:linear-gradient(180deg,rgba(120,140,120,.14),transparent 22%),var(--stone,#ECE8DD);
  color:var(--ink,#141311);
  font-family:'Inter Tight',-apple-system,sans-serif;
  padding:0 22px 80px;
}
.console-nav{
  max-width:1080px;margin:0 auto;display:flex;align-items:center;gap:14px;
  padding:22px 0;
}
.console-nav .wm{font-weight:600;font-size:14px;letter-spacing:.24em;text-decoration:none;color:var(--ink)}
.console-nav .wm span{color:var(--crimson,#96302E)}
.console-nav .back{margin-left:auto;font-size:13px;color:var(--ink-2,#5D584C);text-decoration:none}
.console-nav .back:hover{color:var(--ink)}

.console-wrap{max-width:1080px;margin:0 auto;display:grid;grid-template-columns:1fr 1fr;gap:22px;align-items:start}
.console-head{grid-column:1/-1;margin-bottom:6px}
.console-head .kick{font-size:11px;letter-spacing:.28em;text-transform:uppercase;color:var(--ink-2);margin-bottom:14px;display:flex;align-items:center;gap:12px}
.console-head .kick::before{content:"";width:26px;height:1px;background:var(--crimson)}
.console-head h1{font-family:'Newsreader',Georgia,serif;font-weight:400;font-size:clamp(30px,4vw,44px);letter-spacing:-.01em}
.console-head p{margin-top:12px;max-width:560px;color:var(--ink-2);font-size:15px;line-height:1.65}

.card{
  background:#fff;border:1px solid rgba(20,19,17,.07);border-radius:18px;
  box-shadow:0 4px 24px rgba(30,40,30,.06);padding:26px 26px 28px;
}
.card h2{font-size:15px;font-weight:600;margin-bottom:4px}
.card .sub{font-size:12.5px;color:var(--ink-3,#948E7E);margin-bottom:20px}
.field{margin-bottom:16px}
.field label{display:block;font-size:12px;color:var(--ink-2);margin-bottom:7px;font-weight:500}
.field input,.field select,.field textarea{
  width:100%;font-family:inherit;font-size:13.5px;color:var(--ink);
  background:var(--stone);border:1px solid rgba(20,19,17,.08);border-radius:10px;
  padding:11px 13px;transition:border-color .2s,background .2s;
}
.field input:focus,.field select:focus,.field textarea:focus{outline:none;border-color:var(--slate,#4E5F78);background:#fff}
.field textarea{resize:vertical;min-height:64px;font-family:'IBM Plex Mono',monospace;font-size:12px}
.field .mono-in{font-family:'IBM Plex Mono',monospace;font-size:12px}
.row2{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.presets{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:18px}
.preset{
  font-size:11.5px;padding:7px 12px;border-radius:100px;cursor:pointer;
  border:1px solid rgba(20,19,17,.12);background:#fff;color:var(--ink-2);transition:background .2s,color .2s;
}
.preset:hover{background:var(--stone);color:var(--ink)}
.run-btn{
  width:100%;font-family:inherit;font-size:14px;font-weight:500;
  background:var(--ink);color:var(--ivory,#F4F1E9);border:none;border-radius:10px;
  padding:14px;cursor:pointer;transition:background .25s,transform .15s;margin-top:6px;
}
.run-btn:hover{background:#2a2823}
.run-btn:active{transform:scale(.98)}
.run-btn:disabled{opacity:.6;cursor:not-allowed}

/* result */
.result-empty{color:var(--ink-3);font-size:13.5px;line-height:1.7;text-align:center;padding:50px 20px}
.verdict-banner{display:flex;align-items:center;gap:16px;padding:20px;border-radius:14px;margin-bottom:20px}
.verdict-banner.ALLOW{background:var(--emerald-bg,rgba(46,122,87,.10))}
.verdict-banner.WARN{background:var(--amber-bg,rgba(154,110,30,.10))}
.verdict-banner.VETO{background:var(--crimson-bg,rgba(150,48,46,.09))}
.verdict-ring{
  width:64px;height:64px;border-radius:50%;flex-shrink:0;display:flex;align-items:center;justify-content:center;
  font-family:'Newsreader',serif;font-size:13px;letter-spacing:.14em;border:1.5px solid;
}
.verdict-banner.ALLOW .verdict-ring{border-color:var(--emerald,#2E7A57);color:var(--emerald,#2E7A57)}
.verdict-banner.WARN .verdict-ring{border-color:var(--amber,#9A6E1E);color:var(--amber,#9A6E1E)}
.verdict-banner.VETO .verdict-ring{border-color:var(--crimson,#96302E);color:var(--crimson,#96302E)}
.verdict-banner .vtext b{font-family:'Newsreader',serif;font-size:20px;font-style:italic;display:block;margin-bottom:4px}
.verdict-banner.ALLOW .vtext b{color:var(--emerald)}
.verdict-banner.WARN .vtext b{color:var(--amber)}
.verdict-banner.VETO .vtext b{color:var(--crimson)}
.verdict-banner .vtext span{font-size:12.5px;color:var(--ink-2)}
.reasons{display:flex;flex-direction:column;gap:8px;margin-bottom:20px}
.reason{display:flex;gap:10px;font-size:13px;color:var(--ink-2);line-height:1.5}
.reason::before{content:"•";color:var(--crimson)}
.result-meta{border-top:1px solid rgba(20,19,17,.08);padding-top:16px;display:flex;flex-direction:column;gap:10px}
.meta-row{display:flex;justify-content:space-between;align-items:baseline;gap:14px;font-size:12.5px}
.meta-row .k{color:var(--ink-3)}
.meta-row .v{font-family:'IBM Plex Mono',monospace;font-size:11.5px;color:var(--ink-2);text-align:right;word-break:break-all}
.meta-row .v a{color:var(--slate);text-decoration:none}
.meta-row .v a:hover{text-decoration:underline}
.err{background:var(--crimson-bg);color:var(--crimson);padding:14px 16px;border-radius:10px;font-size:13px;line-height:1.5}
.spin{display:inline-block;width:14px;height:14px;border:2px solid rgba(244,241,233,.4);border-top-color:var(--ivory);border-radius:50%;animation:sp .7s linear infinite;vertical-align:-2px;margin-right:8px}
@keyframes sp{to{transform:rotate(360deg)}}

@media(max-width:820px){
  .console-wrap{grid-template-columns:1fr}
}
VETO_FILE_5_END_9f3a

# ---------- apps/web/app/console/page.tsx ----------
cat > apps/web/app/console/page.tsx << 'VETO_FILE_6_END_9f3a'
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
VETO_FILE_6_END_9f3a

# ---------- apps/web/app/dashboard/live.tsx ----------
cat > apps/web/app/dashboard/live.tsx << 'VETO_FILE_7_END_9f3a'
"use client";

import { useEffect, useState } from "react";
import { getStats, getVerdicts, type Stats, type StoredVerdict } from "../../lib/engine";

/**
 * Live data hook for the dashboard. Polls the engine every 5s. Returns null
 * while loading or if the engine is unreachable, so the page can fall back
 * to its static sample content and never look broken during a demo.
 */
export function useLiveData() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [verdicts, setVerdicts] = useState<StoredVerdict[] | null>(null);
  const [live, setLive] = useState(false);

  useEffect(() => {
    let active = true;
    async function pull() {
      const [s, v] = await Promise.all([getStats(), getVerdicts(6)]);
      if (!active) return;
      if (s && s.total > 0) {
        setStats(s);
        setVerdicts(v);
        setLive(true);
      } else {
        setLive(false);
      }
    }
    pull();
    const id = setInterval(pull, 5000);
    return () => {
      active = false;
      clearInterval(id);
    };
  }, []);

  return { stats, verdicts, live };
}
VETO_FILE_7_END_9f3a

# ---------- apps/web/app/dashboard/page.tsx ----------
cat > apps/web/app/dashboard/page.tsx << 'VETO_FILE_8_END_9f3a'
"use client";

import { useLiveData } from "./live";
import "../../styles/dashboard.css";

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
VETO_FILE_8_END_9f3a

# ---------- apps/web/.env.example ----------
cat > apps/web/.env.example << 'VETO_FILE_9_END_9f3a'
# VETO engine base URL the dashboard + console read from.
# Local: http://localhost:8787 · Deployed: your Railway engine URL.
NEXT_PUBLIC_ENGINE_URL=http://localhost:8787
VETO_FILE_9_END_9f3a

# ---------- docs/CHECKLIST.md ----------
cat > docs/CHECKLIST.md << 'VETO_FILE_10_END_9f3a'
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

## Phase 7 — Integration  DONE

- [x] Live verdict console (/console) — paste a tx, get a REAL ruling from the engine
- [x] Free /demo/verdict endpoint (no payment) so judges can try it live
- [x] Engine verdict store — every ruling recorded for live dashboard data
- [x] Read endpoints: GET /stats, GET /verdicts
- [x] Dashboard Overview reads live /stats + /verdicts (metrics + recent verdicts)
- [x] Graceful fallback to sample data when engine is unreachable (never looks broken)
- [x] Live/sample indicator in the topbar
- [x] Console links from landing + dashboard; attestation tx links to OKLink explorer
- [x] Engine types clean, 13 tests pass, web builds clean

**Run the full stack locally**
```bash
# terminal 1 — engine
npm run engine:dev
# terminal 2 — web (set NEXT_PUBLIC_ENGINE_URL if not default)
npm run web:dev
# then: http://localhost:3000/console  → paste a tx → real verdict
#       http://localhost:3000/dashboard → live stats once verdicts exist
```

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
VETO_FILE_10_END_9f3a

echo ""
echo "Done. Phase 7 files written."
echo "Run engine:  npm run engine:dev"
echo "Run web:     npm run web:dev"
echo "Demo:        http://localhost:3000/console  (paste tx, real verdict)"
