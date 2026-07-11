import type { RuleModule, Finding } from "../lib/types";
import { policies } from "../lib/config";
import { isKnownDrainer, isRegistered } from "../lib/registries";

/**
 * drainer / counterparty — screens recipients and spenders against a
 * known-drainer set and per-policy recipient rules.
 *
 *   - Any counterparty in the drainer set          -> VETO
 *   - registeredRecipientsOnly policy + unregistered recipient -> VETO
 */
export const counterparty: RuleModule = {
  name: "counterparty",
  evaluate(sim, req): Finding[] | null {
    const policy = policies[req.policy];
    const caller = req.tx.from.toLowerCase();
    const findings: Finding[] = [];
    const seen = new Set<string>();

    for (const e of sim.effects) {
      const parties: string[] = [];
      if (e.kind === "transfer" && e.from === caller && e.to) parties.push(e.to);
      if (e.kind === "approval" && e.owner === caller && e.spender)
        parties.push(e.spender);

      for (const p of parties) {
        const addr = p.toLowerCase();
        if (seen.has(addr)) continue;
        seen.add(addr);

        if (isKnownDrainer(addr)) {
          findings.push({
            rule: "counterparty",
            severity: "VETO",
            message: `Counterparty ${short(addr)} matches a known drainer`,
            evidence: { address: addr, source: "drainer-set" },
          });
          continue;
        }

        if (policy.registeredRecipientsOnly && !isRegistered(addr)) {
          findings.push({
            rule: "counterparty",
            severity: "VETO",
            message: `Recipient ${short(
              addr
            )} is not on the registered ledger`,
            evidence: { address: addr, policy: policy.id },
          });
        }
      }
    }

    return findings.length ? findings : null;
  },
};

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
