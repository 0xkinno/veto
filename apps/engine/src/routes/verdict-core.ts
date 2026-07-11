import { simulate, currentBlock } from "../simulator";
import { parseIntent } from "../intent";
import { aggregate } from "../rules";
import { buildEvidence } from "../evidence";
import { attest } from "../lib/attest";
import { record } from "../lib/store";
import { demoEffects } from "../lib/demo-scenarios";
import type { VerdictRequest, VerdictResponse, SimulationResult } from "../lib/types";

/**
 * The full verdict flow, shared by /verdict and reused (in part) by the
 * other instruments. Simulate, diff, run rules, hash evidence, attest.
 *
 * @param paymentTxHash  x402 settlement tx hash (from the gate), bound to
 *                       the attestation as paymentRef so the paid ruling
 *                       is provably tied to its on-chain payment.
 * @param demo           when true, known demo presets get deterministic
 *                       effects so the rules rule as labelled; custom
 *                       transactions still use the live simulator.
 */
export async function runVerdict(
  req: VerdictRequest,
  paymentTxHash?: string,
  demo = false
): Promise<VerdictResponse> {
  const start = Date.now();

  const intent = parseIntent(req.intent, req.tx);
  const normalised: VerdictRequest = { ...req, intent };

  // Demo presets get deterministic effects so rules rule as labelled;
  // everything else uses the live X Layer simulator.
  let sim: SimulationResult;
  const injected = demo ? demoEffects(normalised) : null;
  if (injected) {
    // Real current block so the demo looks live; effects are deterministic.
    let blockNumber = 0;
    try {
      blockNumber = await currentBlock();
    } catch {
      blockNumber = 0;
    }
    sim = { blockNumber, reverted: false, effects: injected, gasUsed: "0" };
  } else {
    sim = await simulate(req.tx);
  }

  // Honeypot check: for any token the caller newly acquired, the engine
  // runs a follow-up sell-simulation and annotates sim.effects with
  // "sell-blocked" / "fee-on-transfer:N" so the honeypot rule can rule on
  // it. Wired against live X Layer once an RPC with fork support is set.
  // const acquired = tokensToSellTest(sim.effects, req.tx.from);
  // await annotateSellSimulations(sim, acquired, req.tx.from);

  const { verdict, findings, reasons } = aggregate(sim, normalised);
  const evidence = buildEvidence(sim, findings, normalised);

  // Attestation is best-effort: a verdict is still valid if the write
  // is pending. The evidence hash is the commitment either way.
  const attestationTx = await attest({
    evidenceHash: evidence.hash,
    verdictHash: evidence.hash, // canonical verdict commitment
    policy: req.policy,
    verdict,
    agent: req.tx.from,
    paymentRef: paymentTxHash,
  }).catch(() => undefined);

  const response: VerdictResponse = {
    verdict,
    reasons,
    findings,
    evidenceHash: evidence.hash,
    attestationTx,
    blockNumber: sim.blockNumber,
    latencyMs: Date.now() - start,
    policy: req.policy,
  };

  // Record every ruling so the dashboard reads live data.
  record(normalised, response);

  return response;
}
