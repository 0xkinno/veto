import { encodeFunctionData } from "viem";
import {
  approvalHistory,
  allowanceOf,
  tokenMeta,
  isContract,
  UNLIMITED_THRESHOLD,
  ERC20_ABI,
} from "../lib/chain";
import { isKnownDrainer } from "../lib/registries";
import type { Verdict } from "../lib/types";

/**
 * /approvals — Approval hygiene.
 *
 * Answers: "Which live allowances expose this wallet to a drain?"
 *
 * Reconstructs every Approval this wallet ever granted, checks which are
 * STILL live on-chain, scores each by drain exposure, and hands back a
 * ready-to-sign revocation transaction for the dangerous ones.
 */

export interface ApprovalFinding {
  token: string;
  symbol: string;
  spender: string;
  allowance: string;        // raw
  unlimited: boolean;
  spenderIsContract: boolean;
  knownDrainer: boolean;
  risk: Verdict;            // ALLOW = fine, WARN = review, VETO = revoke now
  reason: string;
  /** an unsigned tx that sets this allowance to zero */
  revoke: { to: string; data: string; value: string };
}

export interface ApprovalsReport {
  wallet: string;
  scanned: number;          // approval events found
  live: number;             // still-active allowances
  atRisk: number;           // WARN + VETO
  critical: number;         // VETO
  exposureScore: number;    // 0-100
  findings: ApprovalFinding[];
}

function revokeTx(token: string, spender: string) {
  return {
    to: token,
    data: encodeFunctionData({
      abi: ERC20_ABI,
      functionName: "approve",
      args: [spender as `0x${string}`, 0n],
    }),
    value: "0",
  };
}

export async function scanApprovals(wallet: string): Promise<ApprovalsReport> {
  const owner = wallet.toLowerCase();

  let history;
  try {
    history = await approvalHistory(owner);
  } catch {
    throw new Error(
      `chain unreachable — cannot audit ${owner} without live X Layer state`
    );
  }

  // collapse to the latest approval per (token, spender) pair
  const latest = new Map<string, { token: string; spender: string }>();
  for (const a of history) {
    latest.set(`${a.token}:${a.spender}`, { token: a.token, spender: a.spender });
  }

  const findings: ApprovalFinding[] = [];

  for (const { token, spender } of latest.values()) {
    let current: bigint;
    try {
      current = await allowanceOf(token, owner, spender);
    } catch {
      continue; // token not readable — skip rather than fail the report
    }
    if (current === 0n) continue; // already revoked, not live

    const [meta, spenderIsContract] = await Promise.all([
      tokenMeta(token),
      isContract(spender).catch(() => false),
    ]);

    const unlimited = current >= UNLIMITED_THRESHOLD;
    const drainer = isKnownDrainer(spender);

    let risk: Verdict = "ALLOW";
    let reason = "Bounded allowance to a known-shaped spender.";

    if (drainer) {
      risk = "VETO";
      reason = "Spender matches a known drainer. Revoke immediately.";
    } else if (unlimited) {
      risk = "VETO";
      reason = "Unlimited allowance. The spender can drain the full balance at any time.";
    } else if (!spenderIsContract) {
      risk = "WARN";
      reason = "Allowance granted to an externally owned account, not a contract.";
    }

    findings.push({
      token,
      symbol: meta.symbol,
      spender,
      allowance: current.toString(),
      unlimited,
      spenderIsContract,
      knownDrainer: drainer,
      risk,
      reason,
      revoke: revokeTx(token, spender),
    });
  }

  // rank: VETO first, then WARN, then the rest
  const order: Record<Verdict, number> = { VETO: 0, WARN: 1, ALLOW: 2 };
  findings.sort((a, b) => order[a.risk] - order[b.risk]);

  const critical = findings.filter((f) => f.risk === "VETO").length;
  const atRisk = findings.filter((f) => f.risk !== "ALLOW").length;

  // exposure: unlimited/drainer approvals dominate the score
  const exposureScore = Math.min(
    100,
    critical * 34 + (atRisk - critical) * 12
  );

  return {
    wallet: owner,
    scanned: history.length,
    live: findings.length,
    atRisk,
    critical,
    exposureScore,
    findings,
  };
}
