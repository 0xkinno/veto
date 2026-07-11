import type { RuleModule, Finding } from "../lib/types";
import { policies } from "../lib/config";

/**
 * slippage — compares realised price impact against the policy ceiling.
 *
 * Without a quoted reference rate in the request we cannot compute exact
 * slippage, so this rule reasons about what it can see today: if the
 * caller declared a minimum received amount (expects.tokenIn.minAmount)
 * and the realised inbound is materially below it, that shortfall is
 * treated as slippage past the acceptable band.
 *
 * When a quote oracle is wired (Phase 2 follow-up) this compares realised
 * vs expected mid-price directly against policy.slippageCeiling.
 */
export const slippage: RuleModule = {
  name: "slippage",
  evaluate(sim, req): Finding | null {
    const policy = policies[req.policy];
    const min = req.intent.expects?.tokenIn?.minAmount;
    if (!min) return null;

    const caller = req.tx.from.toLowerCase();
    let received = 0n;
    for (const e of sim.effects) {
      if (e.kind === "balance" && e.account === caller && e.amount) {
        const v = BigInt(e.amount);
        if (v > 0n) received += v;
      }
    }
    if (received === 0n) return null;

    // Coarse comparison: treat declared min as base units for now.
    let expected: bigint;
    try {
      expected = BigInt(min);
    } catch {
      return null;
    }
    if (expected === 0n || received >= expected) return null;

    const shortfall = Number(expected - received) / Number(expected);
    if (shortfall <= policy.slippageCeiling) return null;

    return {
      rule: "slippage",
      severity: policy.id === "treasury-strict" ? "VETO" : "WARN",
      message: `Realised output ${(shortfall * 100).toFixed(
        1
      )}% below declared minimum (ceiling ${(
        policy.slippageCeiling * 100
      ).toFixed(1)}%)`,
      evidence: {
        received: received.toString(),
        expected: expected.toString(),
        ceiling: policy.slippageCeiling,
      },
    };
  },
};
