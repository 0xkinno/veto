import { keccak256, toUtf8Bytes } from "ethers";
import type {
  EvidenceBundle,
  Finding,
  SimulationResult,
  VerdictRequest,
} from "../lib/types";

/**
 * Canonicalise a verdict's inputs and outputs into a hash-committed
 * evidence bundle. The hash is what gets written on-chain; the bundle
 * is what lets anyone independently re-derive the verdict.
 *
 * The canonical form is a stable-key-ordered JSON string so the same
 * verdict always hashes to the same value.
 */
export function buildEvidence(
  sim: SimulationResult,
  findings: Finding[],
  req: VerdictRequest
): EvidenceBundle {
  const canonical = stableStringify({
    simulation: sim,
    findings,
    policy: req.policy,
    intent: req.intent,
  });

  const hash = keccak256(toUtf8Bytes(canonical));

  return {
    hash,
    simulation: sim,
    findings,
    policy: req.policy,
    intent: req.intent,
  };
}

/** Deterministic JSON stringify with sorted keys. */
function stableStringify(value: unknown): string {
  return JSON.stringify(value, (_key, val) => {
    if (val && typeof val === "object" && !Array.isArray(val)) {
      return Object.keys(val)
        .sort()
        .reduce<Record<string, unknown>>((acc, k) => {
          acc[k] = (val as Record<string, unknown>)[k];
          return acc;
        }, {});
    }
    return val;
  });
}
