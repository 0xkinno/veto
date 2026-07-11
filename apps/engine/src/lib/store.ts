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
