import type { RuleModule, Finding } from "../lib/types";
import { policies } from "../lib/config";

/**
 * approval-risk — flags approvals that expose the wallet to a drain.
 *
 *   - Unlimited approval to any spender:
 *       treasury-strict (denyUnknownApprovals) -> VETO
 *       otherwise                              -> WARN
 *   - Bounded approval under a permissive policy -> ALLOW (no finding).
 *
 * Undeclared approvals are additionally caught by intent-divergence; this
 * rule reasons purely about the RISK of the approval itself.
 */
export const approvalRisk: RuleModule = {
  name: "approval-risk",
  evaluate(sim, req): Finding[] | null {
    const policy = policies[req.policy];
    const caller = req.tx.from.toLowerCase();
    const findings: Finding[] = [];

    for (const e of sim.effects) {
      if (e.kind !== "approval" || e.owner !== caller) continue;

      if (e.unlimited) {
        findings.push({
          rule: "approval-risk",
          severity: policy.denyUnknownApprovals ? "VETO" : "WARN",
          message: `Unlimited approval to ${short(e.spender)} on ${short(
            e.token
          )}`,
          evidence: { token: e.token, spender: e.spender, unlimited: true },
        });
      } else if (policy.denyUnknownApprovals) {
        findings.push({
          rule: "approval-risk",
          severity: "WARN",
          message: `Approval granted to ${short(
            e.spender
          )} under a strict policy`,
          evidence: { token: e.token, spender: e.spender, amount: e.amount },
        });
      }
    }

    return findings.length ? findings : null;
  },
};

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
