// Core VETO types. Shared across simulator, rules, diff, evidence, and routes.

export type Verdict = "ALLOW" | "WARN" | "VETO";

export type PolicyId = "treasury-strict" | "standard" | "degen-loose";

/** An unsigned EVM transaction as submitted by the caller. */
export interface UnsignedTx {
  from: string;
  to: string;
  data: string; // 0x-prefixed calldata
  value?: string; // wei, as decimal string
  chainId: number; // 196 for X Layer
}

/** What the agent SAYS it is doing. Diffed against simulated effect. */
export interface DeclaredIntent {
  /** Free-text summary, e.g. "Swap 50 USDT for OKB to settle task #4412". */
  summary: string;
  /** Optional structured expectations the parser fills or the caller provides. */
  expects?: {
    tokenOut?: { token: string; maxAmount?: string };
    tokenIn?: { token: string; minAmount?: string };
    approvals?: Array<{ token: string; spender: string; maxAmount?: string }>;
    recipients?: string[];
  };
}

export interface VerdictRequest {
  tx: UnsignedTx;
  intent: DeclaredIntent;
  policy: PolicyId;
}

/** One observed effect from the state diff. */
export interface Effect {
  kind: "transfer" | "approval" | "balance" | "storage" | "revert";
  /** token contract (or "native" for the chain coin). */
  token?: string;
  /** ERC20 symbol/decimals if resolved. */
  symbol?: string;
  decimals?: number;
  /** transfer: sender / recipient. */
  from?: string;
  to?: string;
  /** approval: owner / spender. */
  owner?: string;
  spender?: string;
  /** generic account for balance effects. */
  account?: string;
  /** raw integer amount as a decimal string (wei / token base units). */
  amount?: string;
  /** signed human-readable delta for balance effects. */
  delta?: string;
  /** true when an approval is unlimited (max uint256). */
  unlimited?: boolean;
  detail?: string;
}

export interface SimulationResult {
  blockNumber: number;
  reverted: boolean;
  revertReason?: string;
  effects: Effect[];
  gasUsed: string;
}

/** A single rule's finding. */
export interface Finding {
  rule: string;
  severity: Verdict; // ALLOW = no issue, WARN = soft, VETO = hard
  message: string;
  evidence?: Record<string, unknown>;
}

export interface EvidenceBundle {
  hash: string; // keccak256 of the canonical bundle
  simulation: SimulationResult;
  findings: Finding[];
  policy: PolicyId;
  intent: DeclaredIntent;
}

export interface VerdictResponse {
  verdict: Verdict;
  reasons: string[];
  findings: Finding[];
  evidenceHash: string;
  attestationTx?: string; // X Layer tx hash of the attestation
  blockNumber: number;
  latencyMs: number;
  policy: PolicyId;
}

/** Signature every rule module implements. */
export interface RuleModule {
  name: string;
  evaluate(
    sim: SimulationResult,
    req: VerdictRequest
  ): Finding | Finding[] | null;
}
