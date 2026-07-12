import { JsonRpcProvider, Wallet, Contract, ZeroHash, ZeroAddress } from "ethers";
import type { PolicyId, Verdict } from "./types";
import { config } from "./config";

/**
 * Write a verdict attestation to X Layer via the deployed VetoAttestation
 * contract:
 *
 *   attest(verdictHash, evidenceHash, policyId, agent, verdict, paymentRef)
 *
 * Returns the attestation tx hash, or undefined when the contract address
 * or attester key is not configured (engine still serves verdicts; the
 * evidence hash is the commitment either way).
 */

const VERDICT_ENUM: Record<Verdict, number> = { ALLOW: 1, WARN: 2, VETO: 3 };

const ABI = [
  "function attest(bytes32 verdictHash, bytes32 evidenceHash, bytes32 policyId, address agent, uint8 verdict, bytes32 paymentRef) external",
];

let contract: Contract | null = null;

function getContract(): Contract | null {
  if (!config.attestationAddress || !config.attesterKey) return null;
  if (!contract) {
    const provider = new JsonRpcProvider(config.attestationRpcUrl);
    const wallet = new Wallet(config.attesterKey, provider);
    contract = new Contract(config.attestationAddress, ABI, wallet);
  }
  return contract;
}

export interface AttestArgs {
  evidenceHash: string;
  verdictHash: string;
  policy: PolicyId;
  verdict: Verdict;
  agent?: string;
  paymentRef?: string;
}

export async function attest(args: AttestArgs): Promise<string | undefined> {
  const c = getContract();
  if (!c) return undefined;

  const policyId = policyToBytes32(args.policy);
  const agent = args.agent ?? ZeroAddress;
  const paymentRef = normaliseRef(args.paymentRef);

  const tx = await c.attest(
    args.verdictHash,
    args.evidenceHash,
    policyId,
    agent,
    VERDICT_ENUM[args.verdict],
    paymentRef
  );
  await tx.wait();
  return tx.hash as string;
}

/** Encode a policy id string into bytes32 (right-padded utf8). */
function policyToBytes32(policy: string): string {
  const bytes = Buffer.from(policy, "utf8");
  if (bytes.length > 32) throw new Error("policy id too long");
  const padded = Buffer.alloc(32);
  bytes.copy(padded);
  return "0x" + padded.toString("hex");
}

/** A tx hash is already bytes32; otherwise use the zero hash. */
function normaliseRef(ref?: string): string {
  if (ref && /^0x[0-9a-fA-F]{64}$/.test(ref)) return ref;
  return ZeroHash;
}
