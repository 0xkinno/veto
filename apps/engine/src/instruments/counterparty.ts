import { isContract, codeSize, nativeBalance, txCount } from "../lib/chain";
import { isKnownDrainer, isRegistered } from "../lib/registries";

/**
 * /counterparty — Counterparty pre-check.
 *
 * Answers: "Can this address or contract be trusted before I engage?"
 *
 * Every signal is read live from X Layer. No claim without an on-chain
 * reference — that is the whole point.
 */

export type Grade = "TRUSTED" | "NEUTRAL" | "CAUTION" | "AVOID";

export interface Signal {
  name: string;
  value: string;
  weight: number;   // negative = risk, positive = trust
  note: string;
}

export interface CounterpartyReport {
  address: string;
  type: "contract" | "eoa";
  grade: Grade;
  trustScore: number;      // 0-100
  signals: Signal[];
  summary: string;
  /** every fact here is independently checkable on-chain */
  onChain: {
    isContract: boolean;
    codeSizeBytes: number;
    nativeBalanceWei: string;
    outgoingTxCount: number;
  };
}

export async function checkCounterparty(
  address: string
): Promise<CounterpartyReport> {
  const addr = address.toLowerCase();

  let contract: boolean;
  let size: number;
  let balance: bigint;
  let nonce: number;
  try {
    [contract, size, balance, nonce] = await Promise.all([
      isContract(addr),
      codeSize(addr),
      nativeBalance(addr),
      txCount(addr),
    ]);
  } catch (err) {
    // Never grade an address on data we could not read. Say so instead.
    throw new Error(
      `chain unreachable — cannot grade ${addr} without live X Layer state`
    );
  }

  const signals: Signal[] = [];
  let score = 50; // start neutral

  // --- hard signals ------------------------------------------------------
  if (isKnownDrainer(addr)) {
    signals.push({
      name: "drainer-match",
      value: "positive",
      weight: -100,
      note: "Address appears in the known-drainer set.",
    });
    score = 0;
  }

  if (isRegistered(addr)) {
    signals.push({
      name: "registered-recipient",
      value: "yes",
      weight: +30,
      note: "Address is on the caller's registered ledger.",
    });
    score += 30;
  }

  // --- shape signals -----------------------------------------------------
  if (contract) {
    signals.push({
      name: "bytecode",
      value: `${size} bytes`,
      weight: size > 400 ? +8 : -10,
      note:
        size > 400
          ? "Substantial contract bytecode — consistent with a real protocol."
          : "Very small bytecode. Proxies and minimal forwarders can hide behaviour.",
    });
    score += size > 400 ? 8 : -10;
  } else {
    signals.push({
      name: "account-type",
      value: "externally owned",
      weight: -6,
      note: "Not a contract. Funds sent here are controlled by a private key.",
    });
    score -= 6;
  }

  // --- activity signals --------------------------------------------------
  if (nonce === 0 && !contract) {
    signals.push({
      name: "activity",
      value: "0 outgoing txs",
      weight: -18,
      note: "Fresh address with no history. Common in drain and phishing setups.",
    });
    score -= 18;
  } else if (nonce > 200) {
    signals.push({
      name: "activity",
      value: `${nonce} outgoing txs`,
      weight: +12,
      note: "Long transaction history — an established account.",
    });
    score += 12;
  } else {
    signals.push({
      name: "activity",
      value: `${nonce} outgoing txs`,
      weight: 0,
      note: "Moderate history. Not a strong signal either way.",
    });
  }

  if (balance === 0n && !contract) {
    signals.push({
      name: "balance",
      value: "0",
      weight: -8,
      note: "Zero native balance. Cannot pay its own gas — often a burner.",
    });
    score -= 8;
  }

  score = Math.max(0, Math.min(100, score));

  const grade: Grade =
    score >= 75 ? "TRUSTED" : score >= 50 ? "NEUTRAL" : score >= 25 ? "CAUTION" : "AVOID";

  const summary =
    grade === "AVOID"
      ? "Do not engage. The evidence points to a hostile or throwaway address."
      : grade === "CAUTION"
      ? "Engage only with bounded exposure. Several signals are unfavourable."
      : grade === "TRUSTED"
      ? "Established and consistent with a legitimate counterparty."
      : "Nothing alarming, nothing reassuring. Treat as unknown.";

  return {
    address: addr,
    type: contract ? "contract" : "eoa",
    grade,
    trustScore: score,
    signals,
    summary,
    onChain: {
      isContract: contract,
      codeSizeBytes: size,
      nativeBalanceWei: balance.toString(),
      outgoingTxCount: nonce,
    },
  };
}
