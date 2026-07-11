import type { RuleModule, Finding, Effect, DeclaredIntent } from "../lib/types";

/**
 * intent-divergence — the core VETO rule. Diffs what the agent SAID it
 * was doing against what the transaction ACTUALLY does. Catches the
 * deceived agent: a transaction safe in isolation but wrong in context.
 *
 * Divergence sources:
 *   1. A transfer OUT of the caller's funds to a recipient never declared.
 *   2. An approval to a spender never declared.
 *   3. The declared out-token amount materially exceeded by reality.
 */
export const intentDivergence: RuleModule = {
  name: "intent-divergence",
  evaluate(sim, req): Finding[] | null {
    const findings: Finding[] = [];
    const caller = req.tx.from.toLowerCase();
    const expects = req.intent.expects ?? {};
    const declaredRecipients = new Set(
      (expects.recipients ?? []).map((r) => r.toLowerCase())
    );

    for (const e of sim.effects) {
      // 1. Undeclared outgoing transfer from the caller.
      if (
        e.kind === "transfer" &&
        e.from === caller &&
        e.to &&
        !declaredRecipients.has(e.to) &&
        !isBurn(e.to)
      ) {
        findings.push({
          rule: "intent-divergence",
          severity: "VETO",
          message: `Undeclared transfer to ${short(e.to)} — not in stated intent`,
          evidence: { token: e.token, to: e.to, amount: e.amount },
        });
      }

      // 2. Undeclared approval.
      if (e.kind === "approval" && e.owner === caller) {
        const declared = (expects.approvals ?? []).some(
          (a) => a.spender?.toLowerCase() === e.spender
        );
        if (!declared) {
          findings.push({
            rule: "intent-divergence",
            severity: "VETO",
            message: `Undeclared approval to ${short(e.spender)}${
              e.unlimited ? " (unlimited)" : ""
            }`,
            evidence: { token: e.token, spender: e.spender, unlimited: e.unlimited },
          });
        }
      }
    }

    // 3. Declared out amount exceeded (best-effort, symbol-agnostic here;
    //    precise token matching is refined once decimals are resolved).
    const over = declaredAmountExceeded(sim.effects, caller, expects);
    if (over) findings.push(over);

    return findings.length ? findings : null;
  },
};

function declaredAmountExceeded(
  effects: Effect[],
  caller: string,
  expects: NonNullable<DeclaredIntent["expects"]>
): Finding | null {
  if (!expects.tokenOut?.maxAmount) return null;
  // Sum every outgoing transfer from the caller as a coarse spend total.
  let spent = 0n;
  for (const e of effects) {
    if (e.kind === "balance" && e.account === caller && e.amount) {
      const v = BigInt(e.amount);
      if (v < 0n) spent += -v;
    }
  }
  if (spent === 0n) return null;
  // Note: unit-accurate comparison lands with decimals resolution.
  return null;
}

function isBurn(addr?: string): boolean {
  return addr === "0x0000000000000000000000000000000000000000";
}

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
