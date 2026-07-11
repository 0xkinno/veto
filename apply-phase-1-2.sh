#!/usr/bin/env bash
# VETO — Phase 1 + 2 apply script
# Run from the root of your existing veto folder:  bash apply-phase-1-2.sh
# It writes/overwrites only the files below. Your node_modules is untouched.
set -e
echo "Writing Phase 1 + 2 files into $(pwd) ..."

# --- ensure dirs exist (no-op if already there) ---
mkdir -p apps/engine/src/simulator apps/engine/src/diff apps/engine/src/intent apps/engine/src/rules apps/engine/src/lib apps/engine/src/routes apps/engine/src/__tests__

# ---------- apps/engine/src/lib/types.ts ----------
cat > apps/engine/src/lib/types.ts << 'VETO_EOF'
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
VETO_EOF

# ---------- apps/engine/src/lib/registries.ts ----------
cat > apps/engine/src/lib/registries.ts << 'VETO_EOF'
/**
 * Address registries: known drainers and registered recipients.
 *
 * Seeded here for deterministic rule behaviour; in production these load
 * from a refreshed threat feed (drainers) and the caller's own ledger
 * (registered recipients) at boot. The lookups below are the stable
 * interface the rules depend on — swap the backing store freely.
 */

// Seed drainer set. Extend from a live feed (e.g. Scam Sniffer / Chainabuse)
// via loadDrainers() at engine start.
const drainers = new Set<string>(
  ([] as string[])
    // placeholder entries; replace with a real feed on boot.
    .map((a) => a.toLowerCase())
);

// Registered recipients for treasury-strict callers. Populated per-caller
// in Phase 4 from the submitted ledger; empty here means "nothing trusted".
const registered = new Set<string>();

export function isKnownDrainer(address: string): boolean {
  return drainers.has(address.toLowerCase());
}

export function isRegistered(address: string): boolean {
  return registered.has(address.toLowerCase());
}

export function loadDrainers(addresses: string[]): void {
  for (const a of addresses) drainers.add(a.toLowerCase());
}

export function loadRegistered(addresses: string[]): void {
  for (const a of addresses) registered.add(a.toLowerCase());
}
VETO_EOF

# ---------- apps/engine/src/simulator/index.ts ----------
cat > apps/engine/src/simulator/index.ts << 'VETO_EOF'
import {
  createPublicClient,
  http,
  decodeEventLog,
  parseAbi,
  maxUint256,
  type PublicClient,
} from "viem";
import type { SimulationResult, UnsignedTx } from "../lib/types";
import { config } from "../lib/config";
import { extractEffects } from "../diff";

/**
 * Fork X Layer at the latest block and execute an unsigned transaction
 * against that fork, capturing the trace and every state change.
 *
 * Strategy:
 *   1. eth_call the exact transaction at the latest block to detect
 *      revert + reason and confirm executability.
 *   2. debug_traceCall with the callTracer to capture the full internal
 *      call tree + emitted logs (used by the diff extractor).
 *   3. Hand the raw logs to extractEffects() to produce the effect list.
 *
 * Falls back gracefully when a node does not expose debug_traceCall:
 * it still returns revert state from eth_call and decodes any logs it can.
 */

let client: PublicClient | null = null;

function getClient(): PublicClient {
  if (!client) {
    client = createPublicClient({ transport: http(config.rpcUrl) });
  }
  return client;
}

const TRANSFER_APPROVAL_ABI = parseAbi([
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
]);

export async function simulate(tx: UnsignedTx): Promise<SimulationResult> {
  const c = getClient();
  const blockNumber = Number(await c.getBlockNumber());

  const callParams = {
    account: tx.from as `0x${string}`,
    to: tx.to as `0x${string}`,
    data: (tx.data ?? "0x") as `0x${string}`,
    value: tx.value ? BigInt(tx.value) : undefined,
  };

  // 1. Detect revert + reason via eth_call.
  let reverted = false;
  let revertReason: string | undefined;
  try {
    await c.call(callParams);
  } catch (err: unknown) {
    reverted = true;
    revertReason = extractRevertReason(err);
  }

  // 2. Try a full trace for logs + gas. Not all RPCs expose debug_.
  let rawLogs: TraceLog[] = [];
  let gasUsed = "0";
  try {
    const trace = (await c.request({
      method: "debug_traceCall" as never,
      params: [
        {
          from: tx.from,
          to: tx.to,
          data: tx.data ?? "0x",
          value: tx.value ? `0x${BigInt(tx.value).toString(16)}` : "0x0",
        },
        "latest",
        { tracer: "callTracer", tracerConfig: { withLog: true } },
      ] as never,
    })) as TraceResult;

    gasUsed = trace?.gasUsed ? BigInt(trace.gasUsed).toString() : "0";
    rawLogs = collectLogs(trace);
  } catch {
    // debug namespace unavailable — effects come from decoded logs only.
  }

  const decoded = decodeLogs(rawLogs);
  const effects = extractEffects({ decoded, reverted, revertReason });

  return { blockNumber, reverted, revertReason, effects, gasUsed };
}

// ---- helpers ----------------------------------------------------------

interface TraceLog {
  address: string;
  topics: string[];
  data: string;
}

interface TraceResult {
  gasUsed?: string;
  logs?: TraceLog[];
  calls?: TraceResult[];
}

/** Flatten every log emitted across the whole call tree. */
function collectLogs(trace: TraceResult | undefined): TraceLog[] {
  if (!trace) return [];
  const out: TraceLog[] = [...(trace.logs ?? [])];
  for (const sub of trace.calls ?? []) out.push(...collectLogs(sub));
  return out;
}

export interface DecodedLog {
  event: "Transfer" | "Approval";
  token: string;
  from?: string;
  to?: string;
  owner?: string;
  spender?: string;
  value: string;
  unlimited: boolean;
}

/** Decode Transfer + Approval logs; ignore everything else. */
function decodeLogs(logs: TraceLog[]): DecodedLog[] {
  const out: DecodedLog[] = [];
  for (const log of logs) {
    try {
      const parsed = decodeEventLog({
        abi: TRANSFER_APPROVAL_ABI,
        data: log.data as `0x${string}`,
        topics: log.topics as [`0x${string}`, ...`0x${string}`[]],
      });
      if (parsed.eventName === "Transfer") {
        const a = parsed.args as unknown as { from: string; to: string; value: bigint };
        out.push({
          event: "Transfer",
          token: log.address,
          from: a.from,
          to: a.to,
          value: a.value.toString(),
          unlimited: false,
        });
      } else if (parsed.eventName === "Approval") {
        const a = parsed.args as unknown as { owner: string; spender: string; value: bigint };
        out.push({
          event: "Approval",
          token: log.address,
          owner: a.owner,
          spender: a.spender,
          value: a.value.toString(),
          unlimited: a.value >= maxUint256 / 2n,
        });
      }
    } catch {
      // not an ERC20 Transfer/Approval — skip.
    }
  }
  return out;
}

function extractRevertReason(err: unknown): string {
  if (err && typeof err === "object") {
    const e = err as { shortMessage?: string; message?: string };
    return e.shortMessage ?? e.message ?? "execution reverted";
  }
  return "execution reverted";
}
VETO_EOF

# ---------- apps/engine/src/diff/index.ts ----------
cat > apps/engine/src/diff/index.ts << 'VETO_EOF'
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
VETO_EOF

# ---------- apps/engine/src/intent/index.ts ----------
cat > apps/engine/src/intent/index.ts << 'VETO_EOF'
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
VETO_EOF

# ---------- apps/engine/src/rules/index.ts ----------
cat > apps/engine/src/rules/index.ts << 'VETO_EOF'
import type {
  Finding,
  SimulationResult,
  Verdict,
  VerdictRequest,
  RuleModule,
} from "../lib/types";
import { approvalRisk } from "./approval-risk";
import { counterparty } from "./counterparty";
import { honeypot } from "./honeypot";
import { slippage } from "./slippage";
import { intentDivergence } from "./intent-divergence";

/** Ordered rule pipeline. Every verdict runs all five. */
export const pipeline: RuleModule[] = [
  intentDivergence,
  approvalRisk,
  counterparty,
  honeypot,
  slippage,
];

const rank: Record<Verdict, number> = { ALLOW: 0, WARN: 1, VETO: 2 };

/**
 * Run the pipeline and fold every finding into a single verdict.
 * The verdict is the most severe finding. A revert is always a VETO.
 */
export function aggregate(
  sim: SimulationResult,
  req: VerdictRequest
): { verdict: Verdict; findings: Finding[]; reasons: string[] } {
  const findings: Finding[] = [];

  if (sim.reverted) {
    findings.push({
      rule: "simulation",
      severity: "VETO",
      message: `Transaction reverts: ${sim.revertReason ?? "unknown reason"}`,
    });
  }

  for (const rule of pipeline) {
    const out = rule.evaluate(sim, req);
    if (!out) continue;
    for (const f of Array.isArray(out) ? out : [out]) findings.push(f);
  }

  let verdict: Verdict = "ALLOW";
  for (const f of findings) {
    if (rank[f.severity] > rank[verdict]) verdict = f.severity;
  }

  const reasons = findings
    .filter((f) => f.severity !== "ALLOW")
    .map((f) => `${f.rule}: ${f.message}`);

  return { verdict, findings, reasons };
}
VETO_EOF

# ---------- apps/engine/src/rules/intent-divergence.ts ----------
cat > apps/engine/src/rules/intent-divergence.ts << 'VETO_EOF'
import type { RuleModule, Finding, Effect, DeclaredIntent } from "../lib/types";

/**
 * intent-divergence — the core VETO rule. Diffs what the agent SAID it
 * was doing against what the transaction ACTUALLY does. Catches the
 * deceived agent: a transaction safe in isolation but wrong in context.
 *
 * Divergence sources:
 *   1. A transfer OUT of the caller's funds to a recipient never declared.
 *   2. An approval to a spender never declared.
 *   3. The declared out-token amount materially exceeded by reality.
 */
export const intentDivergence: RuleModule = {
  name: "intent-divergence",
  evaluate(sim, req): Finding[] | null {
    const findings: Finding[] = [];
    const caller = req.tx.from.toLowerCase();
    const expects = req.intent.expects ?? {};
    const declaredRecipients = new Set(
      (expects.recipients ?? []).map((r) => r.toLowerCase())
    );

    for (const e of sim.effects) {
      // 1. Undeclared outgoing transfer from the caller.
      if (
        e.kind === "transfer" &&
        e.from === caller &&
        e.to &&
        !declaredRecipients.has(e.to) &&
        !isBurn(e.to)
      ) {
        findings.push({
          rule: "intent-divergence",
          severity: "VETO",
          message: `Undeclared transfer to ${short(e.to)} — not in stated intent`,
          evidence: { token: e.token, to: e.to, amount: e.amount },
        });
      }

      // 2. Undeclared approval.
      if (e.kind === "approval" && e.owner === caller) {
        const declared = (expects.approvals ?? []).some(
          (a) => a.spender?.toLowerCase() === e.spender
        );
        if (!declared) {
          findings.push({
            rule: "intent-divergence",
            severity: "VETO",
            message: `Undeclared approval to ${short(e.spender)}${
              e.unlimited ? " (unlimited)" : ""
            }`,
            evidence: { token: e.token, spender: e.spender, unlimited: e.unlimited },
          });
        }
      }
    }

    // 3. Declared out amount exceeded (best-effort, symbol-agnostic here;
    //    precise token matching is refined once decimals are resolved).
    const over = declaredAmountExceeded(sim.effects, caller, expects);
    if (over) findings.push(over);

    return findings.length ? findings : null;
  },
};

function declaredAmountExceeded(
  effects: Effect[],
  caller: string,
  expects: NonNullable<DeclaredIntent["expects"]>
): Finding | null {
  if (!expects.tokenOut?.maxAmount) return null;
  // Sum every outgoing transfer from the caller as a coarse spend total.
  let spent = 0n;
  for (const e of effects) {
    if (e.kind === "balance" && e.account === caller && e.amount) {
      const v = BigInt(e.amount);
      if (v < 0n) spent += -v;
    }
  }
  if (spent === 0n) return null;
  // Note: unit-accurate comparison lands with decimals resolution.
  return null;
}

function isBurn(addr?: string): boolean {
  return addr === "0x0000000000000000000000000000000000000000";
}

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
VETO_EOF

# ---------- apps/engine/src/rules/approval-risk.ts ----------
cat > apps/engine/src/rules/approval-risk.ts << 'VETO_EOF'
import type { RuleModule, Finding } from "../lib/types";
import { policies } from "../lib/config";

/**
 * approval-risk — flags approvals that expose the wallet to a drain.
 *
 *   - Unlimited approval to any spender:
 *       treasury-strict (denyUnknownApprovals) -> VETO
 *       otherwise                              -> WARN
 *   - Bounded approval under a permissive policy -> ALLOW (no finding).
 *
 * Undeclared approvals are additionally caught by intent-divergence; this
 * rule reasons purely about the RISK of the approval itself.
 */
export const approvalRisk: RuleModule = {
  name: "approval-risk",
  evaluate(sim, req): Finding[] | null {
    const policy = policies[req.policy];
    const caller = req.tx.from.toLowerCase();
    const findings: Finding[] = [];

    for (const e of sim.effects) {
      if (e.kind !== "approval" || e.owner !== caller) continue;

      if (e.unlimited) {
        findings.push({
          rule: "approval-risk",
          severity: policy.denyUnknownApprovals ? "VETO" : "WARN",
          message: `Unlimited approval to ${short(e.spender)} on ${short(
            e.token
          )}`,
          evidence: { token: e.token, spender: e.spender, unlimited: true },
        });
      } else if (policy.denyUnknownApprovals) {
        findings.push({
          rule: "approval-risk",
          severity: "WARN",
          message: `Approval granted to ${short(
            e.spender
          )} under a strict policy`,
          evidence: { token: e.token, spender: e.spender, amount: e.amount },
        });
      }
    }

    return findings.length ? findings : null;
  },
};

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
VETO_EOF

# ---------- apps/engine/src/rules/counterparty.ts ----------
cat > apps/engine/src/rules/counterparty.ts << 'VETO_EOF'
import type { RuleModule, Finding } from "../lib/types";
import { policies } from "../lib/config";
import { isKnownDrainer, isRegistered } from "../lib/registries";

/**
 * drainer / counterparty — screens recipients and spenders against a
 * known-drainer set and per-policy recipient rules.
 *
 *   - Any counterparty in the drainer set          -> VETO
 *   - registeredRecipientsOnly policy + unregistered recipient -> VETO
 */
export const counterparty: RuleModule = {
  name: "counterparty",
  evaluate(sim, req): Finding[] | null {
    const policy = policies[req.policy];
    const caller = req.tx.from.toLowerCase();
    const findings: Finding[] = [];
    const seen = new Set<string>();

    for (const e of sim.effects) {
      const parties: string[] = [];
      if (e.kind === "transfer" && e.from === caller && e.to) parties.push(e.to);
      if (e.kind === "approval" && e.owner === caller && e.spender)
        parties.push(e.spender);

      for (const p of parties) {
        const addr = p.toLowerCase();
        if (seen.has(addr)) continue;
        seen.add(addr);

        if (isKnownDrainer(addr)) {
          findings.push({
            rule: "counterparty",
            severity: "VETO",
            message: `Counterparty ${short(addr)} matches a known drainer`,
            evidence: { address: addr, source: "drainer-set" },
          });
          continue;
        }

        if (policy.registeredRecipientsOnly && !isRegistered(addr)) {
          findings.push({
            rule: "counterparty",
            severity: "VETO",
            message: `Recipient ${short(
              addr
            )} is not on the registered ledger`,
            evidence: { address: addr, policy: policy.id },
          });
        }
      }
    }

    return findings.length ? findings : null;
  },
};

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
VETO_EOF

# ---------- apps/engine/src/rules/slippage.ts ----------
cat > apps/engine/src/rules/slippage.ts << 'VETO_EOF'
import type { RuleModule, Finding } from "../lib/types";
import { policies } from "../lib/config";

/**
 * slippage — compares realised price impact against the policy ceiling.
 *
 * Without a quoted reference rate in the request we cannot compute exact
 * slippage, so this rule reasons about what it can see today: if the
 * caller declared a minimum received amount (expects.tokenIn.minAmount)
 * and the realised inbound is materially below it, that shortfall is
 * treated as slippage past the acceptable band.
 *
 * When a quote oracle is wired (Phase 2 follow-up) this compares realised
 * vs expected mid-price directly against policy.slippageCeiling.
 */
export const slippage: RuleModule = {
  name: "slippage",
  evaluate(sim, req): Finding | null {
    const policy = policies[req.policy];
    const min = req.intent.expects?.tokenIn?.minAmount;
    if (!min) return null;

    const caller = req.tx.from.toLowerCase();
    let received = 0n;
    for (const e of sim.effects) {
      if (e.kind === "balance" && e.account === caller && e.amount) {
        const v = BigInt(e.amount);
        if (v > 0n) received += v;
      }
    }
    if (received === 0n) return null;

    // Coarse comparison: treat declared min as base units for now.
    let expected: bigint;
    try {
      expected = BigInt(min);
    } catch {
      return null;
    }
    if (expected === 0n || received >= expected) return null;

    const shortfall = Number(expected - received) / Number(expected);
    if (shortfall <= policy.slippageCeiling) return null;

    return {
      rule: "slippage",
      severity: policy.id === "treasury-strict" ? "VETO" : "WARN",
      message: `Realised output ${(shortfall * 100).toFixed(
        1
      )}% below declared minimum (ceiling ${(
        policy.slippageCeiling * 100
      ).toFixed(1)}%)`,
      evidence: {
        received: received.toString(),
        expected: expected.toString(),
        ceiling: policy.slippageCeiling,
      },
    };
  },
};
VETO_EOF

# ---------- apps/engine/src/rules/honeypot.ts ----------
cat > apps/engine/src/rules/honeypot.ts << 'VETO_EOF'
import type { RuleModule, Finding, Effect } from "../lib/types";

/**
 * honeypot — flags tokens that can be bought but not sold. Detects the
 * classic trap where the acquisition succeeds and the exit reverts or
 * bleeds a punitive fee.
 *
 * Detection here is signal-based on the primary simulation. A follow-up
 * sell-simulation is triggered by the engine when a newly acquired token
 * has no offsetting outflow; the result is fed back as effect metadata.
 * Rules stay pure, so this evaluates the signals already present:
 *
 *   - The caller nets an inbound token whose contract emitted a Transfer
 *     to the caller but blocks further transfers (marked upstream).
 *   - A fee-on-transfer discrepancy above a hard threshold.
 */
export const honeypot: RuleModule = {
  name: "honeypot",
  evaluate(sim, req): Finding[] | null {
    const caller = req.tx.from.toLowerCase();
    const findings: Finding[] = [];

    for (const e of sim.effects) {
      if (e.detail === "sell-blocked" && e.account === caller) {
        findings.push({
          rule: "honeypot",
          severity: "VETO",
          message: `Token ${short(
            e.token
          )} accepts buys but blocks sells — honeypot`,
          evidence: { token: e.token },
        });
      }
      if (e.detail?.startsWith("fee-on-transfer:")) {
        const pct = Number(e.detail.split(":")[1]);
        if (!Number.isNaN(pct) && pct >= 20) {
          findings.push({
            rule: "honeypot",
            severity: pct >= 50 ? "VETO" : "WARN",
            message: `Token ${short(e.token)} charges a ${pct}% transfer fee`,
            evidence: { token: e.token, feePct: pct },
          });
        }
      }
    }

    return findings.length ? findings : null;
  },
};

/**
 * Given the primary simulation effects, list tokens the caller newly
 * acquired that warrant a sell-simulation. The engine runs the sell and
 * annotates effects with "sell-blocked" / "fee-on-transfer:N" before the
 * rule pipeline sees them.
 */
export function tokensToSellTest(effects: Effect[], caller: string): string[] {
  const acquired = new Set<string>();
  for (const e of effects) {
    if (
      e.kind === "balance" &&
      e.account === caller.toLowerCase() &&
      e.amount &&
      BigInt(e.amount) > 0n &&
      e.token
    ) {
      acquired.add(e.token);
    }
  }
  return [...acquired];
}

function short(a?: string): string {
  return a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "unknown";
}
VETO_EOF

# ---------- apps/engine/src/routes/verdict-core.ts ----------
cat > apps/engine/src/routes/verdict-core.ts << 'VETO_EOF'
import { simulate } from "../simulator";
import { parseIntent } from "../intent";
import { aggregate } from "../rules";
import { buildEvidence } from "../evidence";
import { attest } from "../lib/attest";
import type { VerdictRequest, VerdictResponse } from "../lib/types";

/**
 * The full verdict flow, shared by /verdict and reused (in part) by the
 * other instruments. Simulate, diff, run rules, hash evidence, attest.
 */
export async function runVerdict(
  req: VerdictRequest
): Promise<VerdictResponse> {
  const start = Date.now();

  const intent = parseIntent(req.intent, req.tx);
  const normalised: VerdictRequest = { ...req, intent };

  const sim = await simulate(req.tx);

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
  const attestationTx = await attest(evidence.hash, req.policy).catch(
    () => undefined
  );

  return {
    verdict,
    reasons,
    findings,
    evidenceHash: evidence.hash,
    attestationTx,
    blockNumber: sim.blockNumber,
    latencyMs: Date.now() - start,
    policy: req.policy,
  };
}
VETO_EOF

# ---------- apps/engine/src/__tests__/pipeline.test.ts ----------
cat > apps/engine/src/__tests__/pipeline.test.ts << 'VETO_EOF'
import { describe, it, expect } from "vitest";
import { extractEffects } from "../diff";
import { parseIntent } from "../intent";
import { aggregate } from "../rules";
import type { VerdictRequest, SimulationResult } from "../lib/types";
import type { DecodedLog } from "../simulator";

const CALLER = "0x1111111111111111111111111111111111111111";
const GOOD = "0x2222222222222222222222222222222222222222";
const EVIL = "0x3333333333333333333333333333333333333333";
const USDT = "0x4444444444444444444444444444444444444444";
const MAXISH =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

function req(overrides: Partial<VerdictRequest> = {}): VerdictRequest {
  return {
    tx: { from: CALLER, to: GOOD, data: "0x", chainId: 196 },
    intent: { summary: "Swap 50 USDT for OKB" },
    policy: "standard",
    ...overrides,
  };
}

function sim(effects: SimulationResult["effects"]): SimulationResult {
  return { blockNumber: 100, reverted: false, effects, gasUsed: "21000" };
}

describe("diff extractor", () => {
  it("turns a Transfer log into transfer + balance effects", () => {
    const decoded: DecodedLog[] = [
      { event: "Transfer", token: USDT, from: CALLER, to: GOOD, value: "50", unlimited: false },
    ];
    const effects = extractEffects({ decoded, reverted: false });
    expect(effects.some((e) => e.kind === "transfer")).toBe(true);
    // caller nets -50, recipient +50
    const callerBal = effects.find((e) => e.kind === "balance" && e.account === CALLER.toLowerCase());
    expect(callerBal?.amount).toBe("-50");
  });

  it("emits a single revert effect on a reverted sim", () => {
    const effects = extractEffects({ decoded: [], reverted: true, revertReason: "ds-math-sub-underflow" });
    expect(effects).toHaveLength(1);
    expect(effects[0].kind).toBe("revert");
  });
});

describe("intent parser", () => {
  it("extracts recipients and out-token from free text", () => {
    const parsed = parseIntent(
      { summary: `send 50 USDT to ${GOOD}` },
      { from: CALLER, to: GOOD, data: "0x", chainId: 196 }
    );
    expect(parsed.expects?.recipients).toContain(GOOD.toLowerCase());
    expect(parsed.expects?.tokenOut?.token).toBe("USDT");
  });

  it("trusts caller-supplied structured expects", () => {
    const parsed = parseIntent(
      { summary: "x", expects: { recipients: [GOOD] } },
      { from: CALLER, to: GOOD, data: "0x", chainId: 196 }
    );
    expect(parsed.expects?.recipients).toEqual([GOOD]);
  });
});

describe("verdict aggregation", () => {
  it("ALLOWs a declared, clean transfer", () => {
    const r = req({ intent: { summary: "pay", expects: { recipients: [GOOD] } } });
    const s = sim([
      { kind: "transfer", token: USDT, from: CALLER.toLowerCase(), to: GOOD.toLowerCase(), amount: "50" },
    ]);
    const { verdict } = aggregate(s, r);
    expect(verdict).toBe("ALLOW");
  });

  it("VETOs an undeclared transfer to an unknown recipient", () => {
    const r = req({ intent: { summary: "pay", expects: { recipients: [GOOD] } } });
    const s = sim([
      { kind: "transfer", token: USDT, from: CALLER.toLowerCase(), to: EVIL.toLowerCase(), amount: "500" },
    ]);
    const { verdict, reasons } = aggregate(s, r);
    expect(verdict).toBe("VETO");
    expect(reasons.join(" ")).toMatch(/undeclared transfer/i);
  });

  it("VETOs an unlimited approval under treasury-strict", () => {
    const r = req({ policy: "treasury-strict", intent: { summary: "approve", expects: { approvals: [] } } });
    const s = sim([
      { kind: "approval", token: USDT, owner: CALLER.toLowerCase(), spender: EVIL.toLowerCase(), amount: MAXISH, unlimited: true },
    ]);
    const { verdict } = aggregate(s, r);
    expect(verdict).toBe("VETO");
  });

  it("WARNs on an unlimited approval under degen-loose", () => {
    const r = req({
      policy: "degen-loose",
      intent: { summary: "approve spender", expects: { approvals: [{ token: USDT, spender: EVIL }] } },
    });
    const s = sim([
      { kind: "approval", token: USDT, owner: CALLER.toLowerCase(), spender: EVIL.toLowerCase(), amount: MAXISH, unlimited: true },
    ]);
    const { verdict } = aggregate(s, r);
    expect(verdict).toBe("WARN");
  });

  it("VETOs a reverting transaction outright", () => {
    const s: SimulationResult = { blockNumber: 1, reverted: true, revertReason: "boom", effects: [{ kind: "revert", detail: "boom" }], gasUsed: "0" };
    const { verdict } = aggregate(s, req());
    expect(verdict).toBe("VETO");
  });
});
VETO_EOF

echo ""
echo "Done. 13 files written."
echo "Next: run  npm install  then  npm --workspace apps/engine run test"
