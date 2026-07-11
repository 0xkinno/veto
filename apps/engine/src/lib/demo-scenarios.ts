import type { Effect, VerdictRequest } from "./types";

/**
 * Deterministic demo scenarios.
 *
 * The live simulator produces effects from real on-chain state. In a demo
 * with placeholder addresses there is no such state, so the rule pipeline
 * would see nothing and return ALLOW for everything — confusing for a
 * viewer clicking a preset labelled "VETO".
 *
 * This module recognises the demo presets by their calldata selector and
 * supplies the effects those transactions WOULD produce on-chain, so the
 * real rule pipeline runs on realistic input and rules exactly as it would
 * in production. The rules are unchanged; only the input is guaranteed.
 *
 * Returns null for anything that is not a known demo preset, so custom
 * transactions still go through the live simulator untouched.
 */

const APPROVE_SELECTOR = "0x095ea7b3"; // ERC20 approve(address,uint256)
const MAX_UINT =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

export function demoEffects(req: VerdictRequest): Effect[] | null {
  const data = (req.tx.data ?? "0x").toLowerCase();
  const from = req.tx.from.toLowerCase();
  const to = req.tx.to.toLowerCase();

  // Preset: "Undeclared approval (VETO)" — an unlimited approval to a
  // spender the agent never declared. Recognised by the approve selector.
  if (data.startsWith(APPROVE_SELECTOR)) {
    return [
      {
        kind: "approval",
        token: "0x4444444444444444444444444444444444444444",
        owner: from,
        spender: to,
        amount: MAX_UINT,
        unlimited: true,
      },
    ];
  }

  // Preset: "Clean swap (ALLOW)" — a declared transfer to the declared
  // recipient, nothing undeclared. Recognised by empty calldata.
  if (data === "0x" || data === "") {
    // In the clean-swap demo the recipient IS the declared destination,
    // so the transfer matches intent and no rule fires. We mark the intent
    // recipient here so intent-divergence sees it as declared.
    if (!req.intent.expects) req.intent.expects = {};
    const recips = new Set(
      (req.intent.expects.recipients ?? []).map((r) => r.toLowerCase())
    );
    recips.add(to);
    req.intent.expects.recipients = [...recips];

    return [
      {
        kind: "transfer",
        token: "0x4444444444444444444444444444444444444444",
        from,
        to,
        amount: "50000000",
      },
      {
        kind: "balance",
        token: "0x4444444444444444444444444444444444444444",
        account: from,
        amount: "-50000000",
      },
    ];
  }

  return null;
}
