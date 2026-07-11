import type {
  Finding,
  SimulationResult,
  Verdict,
  VerdictRequest,
  RuleModule,
} from "../lib/types";
import { approvalRisk } from "./approval-risk";
import { counterparty } from "./counterparty";
import { honeypot } from "./honeypot";
import { slippage } from "./slippage";
import { intentDivergence } from "./intent-divergence";

/** Ordered rule pipeline. Every verdict runs all five. */
export const pipeline: RuleModule[] = [
  intentDivergence,
  approvalRisk,
  counterparty,
  honeypot,
  slippage,
];

const rank: Record<Verdict, number> = { ALLOW: 0, WARN: 1, VETO: 2 };

/**
 * Run the pipeline and fold every finding into a single verdict.
 * The verdict is the most severe finding. A revert is always a VETO.
 */
export function aggregate(
  sim: SimulationResult,
  req: VerdictRequest
): { verdict: Verdict; findings: Finding[]; reasons: string[] } {
  const findings: Finding[] = [];

  if (sim.reverted) {
    findings.push({
      rule: "simulation",
      severity: "VETO",
      message: `Transaction reverts: ${sim.revertReason ?? "unknown reason"}`,
    });
  }

  for (const rule of pipeline) {
    const out = rule.evaluate(sim, req);
    if (!out) continue;
    for (const f of Array.isArray(out) ? out : [out]) findings.push(f);
  }

  let verdict: Verdict = "ALLOW";
  for (const f of findings) {
    if (rank[f.severity] > rank[verdict]) verdict = f.severity;
  }

  const reasons = findings
    .filter((f) => f.severity !== "ALLOW")
    .map((f) => `${f.rule}: ${f.message}`);

  return { verdict, findings, reasons };
}
