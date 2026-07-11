import type { RuleModule, Finding, Effect } from "../lib/types";

/**
 * honeypot — flags tokens that can be bought but not sold. Detects the
 * classic trap where the acquisition succeeds and the exit reverts or
 * bleeds a punitive fee.
 *
 * Detection here is signal-based on the primary simulation. A follow-up
 * sell-simulation is triggered by the engine when a newly acquired token
 * has no offsetting outflow; the result is fed back as effect metadata.
 * Rules stay pure, so this evaluates the signals already present:
 *
 *   - The caller nets an inbound token whose contract emitted a Transfer
 *     to the caller but blocks further transfers (marked upstream).
 *   - A fee-on-transfer discrepancy above a hard threshold.
 */
export const honeypot: RuleModule = {
  name: "honeypot",
  evaluate(sim, req): Finding[] | null {
    const caller = req.tx.from.toLowerCase();
    const findings: Finding[] = [];

    for (const e of sim.effects) {
      if (e.detail === "sell-blocked" && e.account === caller) {
        findings.push({
          rule: "honeypot",
          severity: "VETO",
          message: `Token ${short(
            e.token
          )} accepts buys but blocks sells — honeypot`,
          evidence: { token: e.token },
        });
      }
      if (e.detail?.startsWith("fee-on-transfer:")) {
        const pct = Number(e.detail.split(":")[1]);
        if (!Number.isNaN(pct) && pct >= 20) {
          findings.push({
            rule: "honeypot",
            severity: pct >= 50 ? "VETO" : "WARN",
            message: `Token ${short(e.token)} charges a ${pct}% transfer fee`,
            evidence: { token: e.token, feePct: pct },
          });
        }
      }
    }

    return findings.length ? findings : null;
  },
};

/**
 * Given the primary simulation effects, list tokens the caller newly
 * acquired that warrant a sell-simulation. The engine runs the sell and
 * annotates effects with "sell-blocked" / "fee-on-transfer:N" before the
 * rule pipeline sees them.
 */
export function tokensToSellTest(effects: Effect[], caller: string): string[] {
  const acquired = new Set<string>();
  for (const e of effects) {
    if (
      e.kind === "balance" &&
      e.account === caller.toLowerCase() &&
      e.amount &&
      BigInt(e.amount) > 0n &&
      e.token
    ) {
      acquired.add(e.token);
    }
  }
  return [...acquired];
}

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
