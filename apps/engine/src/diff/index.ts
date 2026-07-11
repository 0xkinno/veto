import type { Effect } from "../lib/types";
import type { DecodedLog } from "../simulator";

interface DiffInput {
  decoded: DecodedLog[];
  reverted: boolean;
  revertReason?: string;
}

/**
 * Turn decoded Transfer/Approval logs into the canonical Effect list the
 * rule pipeline consumes.
 *
 *   Transfer  -> { kind: "transfer", token, from, to, amount }
 *   Approval  -> { kind: "approval", token, owner, spender, amount, unlimited }
 *   revert    -> a single { kind: "revert", detail } effect
 *
 * Net per-account balance deltas are also emitted so slippage / value
 * rules can reason about what the caller actually gained or lost.
 */
export function extractEffects(input: DiffInput): Effect[] {
  if (input.reverted) {
    return [
      {
        kind: "revert",
        detail: input.revertReason ?? "execution reverted",
      },
    ];
  }

  const effects: Effect[] = [];
  // token -> account -> net signed delta (bigint)
  const balances = new Map<string, Map<string, bigint>>();

  for (const log of input.decoded) {
    if (log.event === "Transfer") {
      effects.push({
        kind: "transfer",
        token: log.token.toLowerCase(),
        from: log.from?.toLowerCase(),
        to: log.to?.toLowerCase(),
        amount: log.value,
      });
      bump(balances, log.token, log.from, -BigInt(log.value));
      bump(balances, log.token, log.to, BigInt(log.value));
    } else if (log.event === "Approval") {
      effects.push({
        kind: "approval",
        token: log.token.toLowerCase(),
        owner: log.owner?.toLowerCase(),
        spender: log.spender?.toLowerCase(),
        amount: log.value,
        unlimited: log.unlimited,
      });
    }
  }

  // Emit net balance effects (non-zero only).
  for (const [token, accounts] of balances) {
    for (const [account, delta] of accounts) {
      if (delta === 0n) continue;
      effects.push({
        kind: "balance",
        token: token.toLowerCase(),
        account: account.toLowerCase(),
        amount: delta.toString(),
      });
    }
  }

  return effects;
}

function bump(
  balances: Map<string, Map<string, bigint>>,
  token: string,
  account: string | undefined,
  delta: bigint
) {
  if (!account) return;
  const t = token.toLowerCase();
  const a = account.toLowerCase();
  if (a === "0x0000000000000000000000000000000000000000") return; // mint/burn sink
  if (!balances.has(t)) balances.set(t, new Map());
  const inner = balances.get(t)!;
  inner.set(a, (inner.get(a) ?? 0n) + delta);
}
