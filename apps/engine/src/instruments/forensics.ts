import { decodeEventLog, type Hash } from "viem";
import { chain, ERC20_ABI, UNLIMITED_THRESHOLD } from "../lib/chain";
import { extractEffects } from "../diff";
import { aggregate } from "../rules";
import { buildEvidence } from "../evidence";
import { isKnownDrainer } from "../lib/registries";
import type { DecodedLog } from "../simulator";
import type { Effect, Finding, PolicyId, SimulationResult, Verdict, VerdictRequest } from "../lib/types";

/**
 * /forensics — Post-incident forensics.
 *
 * Answers: "What should have been caught in this historical transaction?"
 *
 * Pulls a real transaction and its receipt from X Layer, reconstructs the
 * exact effects it produced, replays them through the live rule pipeline,
 * and reports the verdict VETO *would* have returned had it been asked.
 *
 * This is evidence-grade: the effects are read from the chain, not simulated.
 */

export interface ForensicsReport {
  txHash: string;
  blockNumber: number;
  from: string;
  to: string | null;
  status: "success" | "reverted";
  policy: PolicyId;
  /** what VETO would have ruled, had it been consulted before the signature */
  wouldHaveRuled: Verdict;
  findings: Finding[];
  reasons: string[];
  effects: Effect[];
  evidenceHash: string;
  postMortem: string;
}

export async function runForensics(
  txHash: string,
  policy: PolicyId = "standard",
  declaredIntent?: string
): Promise<ForensicsReport> {
  const c = chain();

  const [tx, receipt] = await Promise.all([
    c.getTransaction({ hash: txHash as Hash }),
    c.getTransactionReceipt({ hash: txHash as Hash }),
  ]);

  // Decode every Transfer / Approval the transaction actually emitted.
  const decoded: DecodedLog[] = [];
  for (const log of receipt.logs) {
    try {
      const parsed = decodeEventLog({ abi: ERC20_ABI, data: log.data, topics: log.topics });
      if (parsed.eventName === "Transfer") {
        const a = parsed.args as unknown as { from: string; to: string; value: bigint };
        decoded.push({
          event: "Transfer",
          token: log.address,
          from: a.from,
          to: a.to,
          value: a.value.toString(),
          unlimited: false,
        });
      } else if (parsed.eventName === "Approval") {
        const a = parsed.args as unknown as { owner: string; spender: string; value: bigint };
        decoded.push({
          event: "Approval",
          token: log.address,
          owner: a.owner,
          spender: a.spender,
          value: a.value.toString(),
          unlimited: a.value >= UNLIMITED_THRESHOLD,
        });
      }
    } catch {
      /* non-ERC20 log — not part of the value story */
    }
  }

  const reverted = receipt.status === "reverted";
  const effects = extractEffects({ decoded, reverted });

  const sim: SimulationResult = {
    blockNumber: Number(receipt.blockNumber),
    reverted,
    effects,
    gasUsed: receipt.gasUsed.toString(),
  };

  // Replay through the live rule pipeline, exactly as a pre-signature call would.
  const req: VerdictRequest = {
    tx: {
      from: tx.from,
      to: tx.to ?? "0x0000000000000000000000000000000000000000",
      data: tx.input ?? "0x",
      value: tx.value.toString(),
      chainId: 196,
    },
    intent: {
      summary: declaredIntent ?? "(no intent was declared at signing time)",
      // With no declared intent, every effect is undeclared — which is exactly
      // the point: the agent signed without stating what it expected.
      expects: declaredIntent ? undefined : { recipients: [] },
    },
    policy,
  };

  const { verdict, findings, reasons } = aggregate(sim, req);
  const evidence = buildEvidence(sim, findings, req);

  // Post-mortem: name the thing that did the damage.
  const drained = effects.find(
    (e) => e.kind === "approval" && e.unlimited && e.spender && isKnownDrainer(e.spender)
  );
  const unlimited = effects.find((e) => e.kind === "approval" && e.unlimited);

  let postMortem: string;
  if (drained) {
    postMortem =
      "This transaction granted an unlimited allowance to a known drainer. VETO would have refused the signature before it was ever sent.";
  } else if (unlimited) {
    postMortem =
      "This transaction granted an unlimited allowance. Under any policy stricter than degen-loose, VETO would have refused it.";
  } else if (reverted) {
    postMortem =
      "This transaction reverted on-chain. VETO simulates before signing, so the gas would never have been spent.";
  } else if (verdict === "VETO") {
    postMortem =
      "VETO would have refused this signature. The effects diverge from anything a caller would reasonably have declared.";
  } else if (verdict === "WARN") {
    postMortem =
      "VETO would have flagged this transaction and signed it under caution.";
  } else {
    postMortem =
      "VETO would have cleared this transaction. No rule was triggered by its on-chain effects.";
  }

  return {
    txHash,
    blockNumber: Number(receipt.blockNumber),
    from: tx.from.toLowerCase(),
    to: tx.to ? tx.to.toLowerCase() : null,
    status: reverted ? "reverted" : "success",
    policy,
    wouldHaveRuled: verdict,
    findings,
    reasons,
    effects,
    evidenceHash: evidence.hash,
    postMortem,
  };
}
