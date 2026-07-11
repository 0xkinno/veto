import type { DeclaredIntent, UnsignedTx } from "../lib/types";

/**
 * Normalise a caller's declared intent into a structured object the
 * intent-divergence rule can diff against simulated effects.
 *
 * If the caller already supplied `expects`, it is trusted and returned.
 * Otherwise a lightweight extraction pass pulls addresses, token amounts,
 * and action verbs out of the free-text summary. This is deterministic
 * and dependency-free; a stronger LLM extraction pass can slot in later
 * behind the same function signature without touching callers.
 */
export function parseIntent(
  intent: DeclaredIntent,
  tx: UnsignedTx
): DeclaredIntent {
  if (intent.expects && Object.keys(intent.expects).length > 0) {
    return intent;
  }

  const summary = intent.summary ?? "";
  const expects: NonNullable<DeclaredIntent["expects"]> = {};

  // Explicit recipient addresses named in the summary.
  const addresses = matchAll(summary, /0x[a-fA-F0-9]{40}/g).map((a) =>
    a.toLowerCase()
  );
  if (addresses.length) expects.recipients = unique(addresses);

  // The `to` of the tx is an implicit expected counterparty.
  if (tx.to) {
    expects.recipients = unique([
      ...(expects.recipients ?? []),
      tx.to.toLowerCase(),
    ]);
  }

  // "approve" / "allowance" language flags an expected approval.
  if (/\b(approve|approval|allowance)\b/i.test(summary)) {
    expects.approvals = [];
  }

  // "swap/send/transfer/pay <amount> <TOKEN>" -> expected outgoing token.
  const out = summary.match(
    /\b(?:swap|send|transfer|pay|spend)\s+([\d.,]+)\s*([A-Z]{2,10})\b/
  );
  if (out) {
    expects.tokenOut = { token: out[2], maxAmount: out[1].replace(/,/g, "") };
  }

  // "for/to receive <amount?> <TOKEN>" -> expected incoming token.
  const inc = summary.match(
    /\b(?:for|receive|get|into)\s+([\d.,]+)?\s*([A-Z]{2,10})\b/
  );
  if (inc) {
    expects.tokenIn = {
      token: inc[2],
      minAmount: inc[1] ? inc[1].replace(/,/g, "") : undefined,
    };
  }

  return { ...intent, expects };
}

function matchAll(s: string, re: RegExp): string[] {
  return s.match(re) ?? [];
}

function unique<T>(arr: T[]): T[] {
  return [...new Set(arr)];
}
