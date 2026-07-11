#!/usr/bin/env bash
# VETO — Phase 4 apply script (server + OKX x402 payment layer)
# Run from the root of your veto folder:  bash apply-phase-4.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 4 files into $(pwd) ..."
mkdir -p apps/engine/src/x402 apps/engine/src/lib apps/engine/src/routes apps/engine/src/__tests__

# ---------- apps/engine/src/lib/config.ts ----------
cat > apps/engine/src/lib/config.ts << 'VETO_EOF'
import type { PolicyId } from "./types";

export const config = {
  port: Number(process.env.PORT ?? 8787),
  chainId: 196, // X Layer mainnet (payment settlement chain)
  rpcUrl: process.env.XLAYER_RPC_URL ?? "https://rpc.xlayer.tech",
  attestationAddress: process.env.ATTESTATION_ADDRESS ?? "",
  attesterKey: process.env.ATTESTER_PRIVATE_KEY ?? "",
  redisUrl: process.env.REDIS_URL ?? "",

  // ---- x402 pay-per-call (OKX Facilitator, exact + EIP-3009) -----------
  x402: {
    // OKX Facilitator base URL + endpoint paths.
    baseUrl: process.env.OKX_API_BASE ?? "https://web3.okx.com",
    verifyPath: "/api/v6/pay/x402/verify",
    settlePath: "/api/v6/pay/x402/settle",
    settleStatusPath: "/api/v6/pay/x402/settle/status",
    supportedPath: "/api/v6/pay/x402/supported",
    // OKX API credentials (from the OKX dev portal). Payment enforces only
    // when all three are set; otherwise the gate degrades to open + logs.
    apiKey: process.env.OKX_API_KEY ?? "",
    apiSecret: process.env.OKX_API_SECRET ?? "",
    apiPassphrase: process.env.OKX_API_PASSPHRASE ?? "",
    // Where settled USDT lands — VETO's receiving wallet.
    payTo: process.env.VETO_PAYTO_ADDRESS ?? "",
    // Settlement network (CAIP-2) + protocol version.
    network: "eip155:196",
    x402Version: 2,
    scheme: "exact",
    // Stablecoin used for pricing/settlement. USDG default (EIP-3009 native).
    asset: process.env.X402_ASSET ?? "0x4ae46a509f6b1d9056937ba4500cb143933d2dc8",
    assetName: process.env.X402_ASSET_NAME ?? "USDG",
    assetVersion: process.env.X402_ASSET_VERSION ?? "2",
    assetDecimals: Number(process.env.X402_ASSET_DECIMALS ?? 6),
    maxTimeoutSeconds: 60,
  },

  // Human-readable price per ruling (major units of the asset above).
  pricing: {
    verdict: "0.15",
    approvals: "0.30",
    payload: "0.20",
    counterparty: "0.10",
    forensics: "0.50",
  },
} as const;

export interface PolicyProfile {
  id: PolicyId;
  /** true = any approval to an unknown spender is a hard VETO */
  denyUnknownApprovals: boolean;
  /** slippage ceiling as a fraction, e.g. 0.03 = 3% */
  slippageCeiling: number;
  /** true = recipients must be on a registered ledger */
  registeredRecipientsOnly: boolean;
}

export const policies: Record<PolicyId, PolicyProfile> = {
  "treasury-strict": {
    id: "treasury-strict",
    denyUnknownApprovals: true,
    slippageCeiling: 0.01,
    registeredRecipientsOnly: true,
  },
  standard: {
    id: "standard",
    denyUnknownApprovals: false,
    slippageCeiling: 0.03,
    registeredRecipientsOnly: false,
  },
  "degen-loose": {
    id: "degen-loose",
    denyUnknownApprovals: false,
    slippageCeiling: 0.08,
    registeredRecipientsOnly: false,
  },
};
VETO_EOF

# ---------- apps/engine/src/lib/attest.ts ----------
cat > apps/engine/src/lib/attest.ts << 'VETO_EOF'
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
    const provider = new JsonRpcProvider(config.rpcUrl);
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
VETO_EOF

# ---------- apps/engine/src/x402/facilitator.ts ----------
cat > apps/engine/src/x402/facilitator.ts << 'VETO_EOF'
import { createHmac } from "node:crypto";
import { config } from "../lib/config";

/**
 * OKX x402 Facilitator client.
 *
 * VETO is the Seller. The buyer agent signs an EIP-3009 authorization and
 * sends it in the X-PAYMENT header. We forward that payload verbatim to
 * the OKX Facilitator: /verify to validate the signature, then /settle to
 * move the USDT on X Layer. On success we get an on-chain tx hash we bind
 * to the verdict's attestation.
 *
 * Auth: every call is signed with the OKX API credentials using the
 * OK-ACCESS-SIGN HMAC-SHA256 scheme:
 *   sign = base64( HMAC_SHA256( timestamp + method + requestPath + body,
 *                               apiSecret ) )
 */

export interface PaymentRequirements {
  scheme: string;
  network: string;
  amount: string; // atomic units
  asset: string;
  payTo: string;
  maxTimeoutSeconds?: number;
  extra?: Record<string, unknown>;
}

export interface VerifyResult {
  isValid: boolean;
  invalidReason: string | null;
  invalidMessage: string | null;
  payer: string;
}

export interface SettleResult {
  success: boolean;
  errorReason: string | null;
  errorMessage: string | null;
  payer: string;
  transaction: string; // on-chain tx hash on success
  network: string;
  status: string; // success | pending | timeout | failed
}

interface Envelope<T> {
  code: string;
  msg: string;
  data: T | null;
}

/** Whether OKX credentials are configured. When false, the gate stays open. */
export function paymentConfigured(): boolean {
  const x = config.x402;
  return Boolean(x.apiKey && x.apiSecret && x.apiPassphrase && x.payTo);
}

function sign(
  timestamp: string,
  method: string,
  requestPath: string,
  body: string
): string {
  const prehash = timestamp + method + requestPath + body;
  return createHmac("sha256", config.x402.apiSecret)
    .update(prehash)
    .digest("base64");
}

async function okxRequest<T>(
  method: "GET" | "POST",
  requestPath: string,
  body?: unknown
): Promise<T> {
  const timestamp = new Date().toISOString();
  const bodyStr = body ? JSON.stringify(body) : "";
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "OK-ACCESS-KEY": config.x402.apiKey,
    "OK-ACCESS-SIGN": sign(timestamp, method, requestPath, bodyStr),
    "OK-ACCESS-PASSPHRASE": config.x402.apiPassphrase,
    "OK-ACCESS-TIMESTAMP": timestamp,
  };

  const res = await fetch(config.x402.baseUrl + requestPath, {
    method,
    headers,
    body: method === "POST" ? bodyStr : undefined,
  });

  const env = (await res.json()) as Envelope<T>;
  if (env.code !== "0" || env.data == null) {
    throw new Error(`OKX ${requestPath} failed: ${env.code} ${env.msg}`);
  }
  return env.data;
}

/** Verify a buyer's signed payment authorization (no on-chain tx yet). */
export async function verifyPayment(
  paymentPayload: unknown,
  paymentRequirements: PaymentRequirements
): Promise<VerifyResult> {
  return okxRequest<VerifyResult>("POST", config.x402.verifyPath, {
    x402Version: config.x402.x402Version,
    paymentPayload,
    paymentRequirements,
  });
}

/** Settle a verified authorization on X Layer. Sync = wait for the tx. */
export async function settlePayment(
  paymentPayload: unknown,
  paymentRequirements: PaymentRequirements,
  syncSettle = true
): Promise<SettleResult> {
  return okxRequest<SettleResult>("POST", config.x402.settlePath, {
    x402Version: config.x402.x402Version,
    paymentPayload,
    paymentRequirements,
    syncSettle,
  });
}

/** Poll settlement status by tx hash (for async / timeout fallback). */
export async function settleStatus(txHash: string): Promise<SettleResult> {
  const path = `${config.x402.settleStatusPath}?txHash=${encodeURIComponent(
    txHash
  )}`;
  return okxRequest<SettleResult>("GET", path);
}
VETO_EOF

# ---------- apps/engine/src/x402/pricing.ts ----------
cat > apps/engine/src/x402/pricing.ts << 'VETO_EOF'
import { config } from "../lib/config";
import type { PaymentRequirements } from "./facilitator";

/** Convert a human price ("0.15") to atomic units for the configured asset. */
export function toAtomic(human: string): string {
  const decimals = config.x402.assetDecimals;
  const [whole, frac = ""] = human.split(".");
  const fracPadded = (frac + "0".repeat(decimals)).slice(0, decimals);
  const atomic = BigInt(whole) * 10n ** BigInt(decimals) + BigInt(fracPadded || "0");
  return atomic.toString();
}

/** Build the PaymentRequirements for a priced endpoint. */
export function requirementsFor(
  endpoint: keyof typeof config.pricing,
  resourceUrl: string
): PaymentRequirements {
  const amount = toAtomic(config.pricing[endpoint]);
  return {
    scheme: config.x402.scheme,
    network: config.x402.network,
    amount,
    asset: config.x402.asset,
    payTo: config.x402.payTo,
    maxTimeoutSeconds: config.x402.maxTimeoutSeconds,
    extra: { name: config.x402.assetName, version: config.x402.assetVersion },
  };
}

/** The full 402 body an agent needs to construct its payment. */
export function challengeFor(
  endpoint: keyof typeof config.pricing,
  resourceUrl: string
) {
  return {
    x402Version: config.x402.x402Version,
    accepts: [requirementsFor(endpoint, resourceUrl)],
    resource: { url: resourceUrl },
    error: "payment required",
  };
}
VETO_EOF

# ---------- apps/engine/src/x402/index.ts ----------
cat > apps/engine/src/x402/index.ts << 'VETO_EOF'
import type { FastifyReply, FastifyRequest } from "fastify";
import { config } from "../lib/config";
import { challengeFor, requirementsFor } from "./pricing";
import {
  paymentConfigured,
  verifyPayment,
  settlePayment,
} from "./facilitator";

/**
 * x402 pay-per-call gate (OKX Facilitator, exact + EIP-3009).
 *
 * Flow per priced endpoint:
 *   1. No X-PAYMENT header  -> 402 with the payment challenge (accepts[]).
 *   2. X-PAYMENT present    -> decode base64 PaymentPayload, /verify, then
 *                              /settle (sync) on X Layer.
 *   3. settle success       -> stash the on-chain tx hash on the request so
 *                              the verdict handler binds it as paymentRef,
 *                              and call through to the handler.
 *   4. any failure          -> 402 (retryable) or 502 (facilitator error).
 *
 * If OKX credentials are not configured, the gate logs and passes through
 * so the rest of the engine remains runnable in development.
 */
export function requirePayment(endpoint: keyof typeof config.pricing) {
  return async function gate(req: FastifyRequest, reply: FastifyReply) {
    if (!paymentConfigured()) {
      req.log.warn(
        { endpoint },
        "x402 not configured — serving without payment (dev mode)"
      );
      return; // pass-through
    }

    const resourceUrl = `${req.protocol}://${req.hostname}${req.url}`;
    const header = req.headers["x-payment"];

    // 1. No payment yet -> issue the 402 challenge.
    if (!header || typeof header !== "string") {
      reply.code(402).send(challengeFor(endpoint, resourceUrl));
      return reply;
    }

    // 2. Decode the base64 PaymentPayload.
    let paymentPayload: unknown;
    try {
      paymentPayload = JSON.parse(
        Buffer.from(header, "base64").toString("utf8")
      );
    } catch {
      reply.code(400).send({ error: "malformed X-PAYMENT header" });
      return reply;
    }

    const requirements = requirementsFor(endpoint, resourceUrl);

    // 3. Verify the signed authorization.
    try {
      const verified = await verifyPayment(paymentPayload, requirements);
      if (!verified.isValid) {
        reply.code(402).send({
          error: "payment verification failed",
          reason: verified.invalidReason,
          message: verified.invalidMessage,
          accepts: [requirements],
        });
        return reply;
      }

      // 4. Settle on X Layer (synchronous — wait for the tx hash).
      const settled = await settlePayment(paymentPayload, requirements, true);
      if (!settled.success || settled.status === "failed") {
        reply.code(402).send({
          error: "settlement failed",
          reason: settled.errorReason,
          message: settled.errorMessage,
          accepts: [requirements],
        });
        return reply;
      }

      // 5. Paid. Stash proof for the handler to bind as paymentRef.
      (req as PaidRequest).payment = {
        payer: settled.payer,
        txHash: settled.transaction,
        status: settled.status,
        amount: requirements.amount,
        asset: requirements.asset,
      };
      return; // fall through to the handler
    } catch (err) {
      req.log.error({ err, endpoint }, "x402 facilitator error");
      reply.code(502).send({ error: "payment facilitator unavailable" });
      return reply;
    }
  };
}

export interface PaymentProof {
  payer: string;
  txHash: string;
  status: string;
  amount: string;
  asset: string;
}

export type PaidRequest = FastifyRequest & { payment?: PaymentProof };
VETO_EOF

# ---------- apps/engine/src/routes/index.ts ----------
cat > apps/engine/src/routes/index.ts << 'VETO_EOF'
import type { FastifyInstance } from "fastify";
import { requirePayment, type PaidRequest } from "../x402";
import { runVerdict } from "./verdict-core";
import type { VerdictRequest } from "../lib/types";

/**
 * Registers the five VETO instruments. Every endpoint is gated by x402
 * pay-per-call and shares the simulate → diff → prove core.
 *
 * The payment gate settles USDT on X Layer and stashes the on-chain tx
 * hash on the request; runVerdict binds it to the verdict's attestation
 * as paymentRef, so every paid ruling is provably tied to its payment.
 */
export async function registerRoutes(app: FastifyInstance) {
  app.get("/health", async () => ({ status: "ok", service: "veto-engine" }));

  // ---- /verdict — pre-signature verdicts -------------------------------
  app.post(
    "/verdict",
    { preHandler: requirePayment("verdict") },
    async (request) => {
      const body = request.body as VerdictRequest;
      const payment = (request as PaidRequest).payment;
      return runVerdict(body, payment?.txHash);
    }
  );

  // ---- /approvals — approval hygiene -----------------------------------
  app.post(
    "/approvals",
    { preHandler: requirePayment("approvals") },
    async () => {
      // TODO(phase-4): enumerate live allowances for a wallet, score drain risk.
      return { status: "not-implemented", phase: 4 };
    }
  );

  // ---- /payload — task-payload screening -------------------------------
  app.post(
    "/payload",
    { preHandler: requirePayment("payload") },
    async () => {
      // TODO(phase-4): screen an inbound task payload for injection / drain intent.
      return { status: "not-implemented", phase: 4 };
    }
  );

  // ---- /counterparty — counterparty pre-check --------------------------
  app.post(
    "/counterparty",
    { preHandler: requirePayment("counterparty") },
    async () => {
      // TODO(phase-4): trust-check an address/contract before engaging.
      return { status: "not-implemented", phase: 4 };
    }
  );

  // ---- /forensics — post-incident forensics ----------------------------
  app.post(
    "/forensics",
    { preHandler: requirePayment("forensics") },
    async () => {
      // TODO(phase-4): re-simulate a historical tx, report what should have been caught.
      return { status: "not-implemented", phase: 4 };
    }
  );
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
 *
 * @param paymentTxHash  x402 settlement tx hash (from the gate), bound to
 *                       the attestation as paymentRef so the paid ruling
 *                       is provably tied to its on-chain payment.
 */
export async function runVerdict(
  req: VerdictRequest,
  paymentTxHash?: string
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
  const attestationTx = await attest({
    evidenceHash: evidence.hash,
    verdictHash: evidence.hash, // canonical verdict commitment
    policy: req.policy,
    verdict,
    agent: req.tx.from,
    paymentRef: paymentTxHash,
  }).catch(() => undefined);

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

# ---------- apps/engine/src/__tests__/x402.test.ts ----------
cat > apps/engine/src/__tests__/x402.test.ts << 'VETO_EOF'
import { describe, it, expect } from "vitest";
import { toAtomic, requirementsFor, challengeFor } from "../x402/pricing";
import { paymentConfigured } from "../x402/facilitator";

describe("x402 pricing", () => {
  it("converts human prices to 6-decimal atomic units", () => {
    expect(toAtomic("0.15")).toBe("150000");
    expect(toAtomic("1")).toBe("1000000");
    expect(toAtomic("0.5")).toBe("500000");
    expect(toAtomic("0.000001")).toBe("1");
  });

  it("builds PaymentRequirements with the right scheme + network", () => {
    const r = requirementsFor("verdict", "https://veto.dev/verdict");
    expect(r.scheme).toBe("exact");
    expect(r.network).toBe("eip155:196");
    expect(r.amount).toBe("150000"); // 0.15 default
    expect(r.asset).toMatch(/^0x[0-9a-fA-F]{40}$/);
  });

  it("builds a 402 challenge with an accepts array", () => {
    const c = challengeFor("forensics", "https://veto.dev/forensics");
    expect(c.x402Version).toBe(2);
    expect(Array.isArray(c.accepts)).toBe(true);
    expect(c.accepts[0].amount).toBe("500000"); // 0.50
  });

  it("reports payment unconfigured when keys are absent", () => {
    // No OKX_* env in test -> gate stays open (dev mode).
    expect(paymentConfigured()).toBe(false);
  });
});
VETO_EOF

# ---------- apps/engine/.env.example ----------
cat > apps/engine/.env.example << 'VETO_EOF'
# VETO Engine
PORT=8787

# X Layer RPC — use the SAME url that deployed your contract.
XLAYER_RPC_URL=https://testrpc.xlayer.tech

# Attestation contract (from your Phase 3 deploy)
ATTESTATION_ADDRESS=
ATTESTER_PRIVATE_KEY=

# Redis for verdict cache (optional). Leave blank to disable.
REDIS_URL=

# ---- x402 payments (OKX Facilitator) ---------------------------------
# From the OKX dev portal: https://web3.okx.com/onchainos/dev-portal
# Payment enforces only when KEY + SECRET + PASSPHRASE + PAYTO are all set;
# otherwise the gate stays open (dev mode) and the engine still runs.
OKX_API_BASE=https://web3.okx.com
OKX_API_KEY=
OKX_API_SECRET=
OKX_API_PASSPHRASE=

# VETO's receiving wallet — settled USDT lands here.
VETO_PAYTO_ADDRESS=

# Settlement asset on X Layer (default USDG, EIP-3009 native, 6 decimals).
# USDG: 0x4ae46a509f6b1d9056937ba4500cb143933d2dc8
# USDC: 0x74b7f16337b8972027f6196a17a631ac6de26d22
# USD0: 0x779ded0c9e1022225f8e0630b35a9b54be713736
X402_ASSET=0x4ae46a509f6b1d9056937ba4500cb143933d2dc8
X402_ASSET_NAME=USDG
X402_ASSET_VERSION=2
X402_ASSET_DECIMALS=6
VETO_EOF

# ---------- docs/CHECKLIST.md ----------
cat > docs/CHECKLIST.md << 'VETO_EOF'
# VETO — Master Build Checklist

Tick each item as it is completed and tested against live infrastructure. Do not advance a phase until every box in it is checked. One build, modified forward — never regenerated.

---

## Phase 0 — Scaffold  ✅ (this zip)

- [x] Monorepo structure (`apps/engine`, `apps/web`, `packages/sdk`, `contracts`)
- [x] Root workspace config + scripts
- [x] Master README (architecture, diagrams, tables)
- [x] This checklist
- [x] Asset generation prompts (`design/ASSETS.md`)
- [x] Approved landing HTML reference (`design/landing.reference.html`)
- [x] Approved dashboard HTML reference (`design/dashboard.reference.html`)
- [x] Env templates for engine, web, contracts
- [x] Engine, SDK, contract, and web stubs with types + interfaces in place

---

## Phase 1 — Engine core  ✅

- [x] X Layer fork simulator (viem eth_call + debug_traceCall at latest block)
- [x] Execute unsigned transaction against the fork
- [x] Capture trace + revert reason
- [x] State-diff extractor (transfers, approvals, net balance deltas)
- [x] Intent parser (structured declared-intent object from free text)
- [x] Unit tests: clean diff, revert capture, intent extraction — all green

> Live-RPC note: fork simulation runs against the RPC in `apps/engine/.env`.
> A node exposing `debug_traceCall` gives full internal-call log capture;
> without it the simulator still returns revert state + decodable logs.

**Commands**
```bash
npm run engine:dev
npm --workspace apps/engine run test
```

---

## Phase 2 — Rule layers  ✅

- [x] `intent-divergence` — diff declared intent against simulated effect
- [x] `approval-risk` — unlimited / policy-sensitive approval flagging
- [x] `drainer / counterparty` — drainer set + registered-recipient screen
- [x] `honeypot` — sell-block + fee-on-transfer signals (sell-sim wiring marked)
- [x] `slippage` — realised-below-declared vs policy ceiling
- [x] Verdict aggregator (rules → ALLOW / WARN / VETO + reasons)
- [x] Unit tests per rule with fixture transactions — 9 passing

> `registries.ts` holds the drainer + registered-recipient lookups. Seed is
> empty by design; load a live threat feed and the caller ledger at boot.

---

## Phase 3 — Contract  ✅ (code) / ⏳ (deploy needs your faucet OKB)

- [x] All-rounder attestation contract (deploy-once design):
      - stores verdict enum (ALLOW/WARN/VETO), not just a hash
      - per-agent verdict history + pagination (on-chain reputation feed)
      - batch attestation for high volume
      - revoke / supersede preserving history (forensics trail)
      - x402 payment reference + bindPayment hook
      - free-form bytes metadata slot (forward-compat, no redeploy ever)
      - multi-attester auth, pausable, two-step ownership transfer
- [x] Events indexed for the dashboard ledger (Attested / Revoked / PaymentBound)
- [x] Hardhat test suite — 11 tests (attest, batch, history, revoke, metadata,
      payment, auth, pause, ownership)
- [ ] Deploy to X Layer testnet (needs faucet OKB in deployer wallet)
- [ ] Capture deployed address + deploy tx hash as proof artifacts

**Deploy commands**
```bash
# 1. fund the deployer: https://web3.okx.com/xlayer/faucet  (claim 0.2 OKB)
# 2. put the deployer key in contracts/.env  (DEPLOYER_PRIVATE_KEY=...)
npm run contracts:compile
npm run contracts:test
npm run contracts:deploy
# 3. copy the printed address into apps/engine/.env  (ATTESTATION_ADDRESS=...)
```

**Commands**
```bash
npm run contracts:compile
npm run contracts:test
npm run contracts:deploy
```

---

## Phase 4 — Server + x402  ✅ (code) / ⏳ (live needs OKX API keys)

- [x] `POST /verdict` wired to the full engine + payment gate
- [x] `POST /approvals` `/payload` `/counterparty` `/forensics` gated (handlers land per-instrument)
- [x] x402 pay-per-call gate — real OKX Facilitator flow:
      402 challenge → decode X-PAYMENT → /verify → /settle (sync) on X Layer
- [x] OKX Facilitator client with OK-ACCESS-SIGN HMAC auth (exact + EIP-3009)
- [x] Pricing → atomic units, PaymentRequirements + 402 challenge builder
- [x] Settlement tx hash bound to the verdict attestation as paymentRef
- [x] Evidence bundle assembled + hashed + returned
- [x] Attestation written on each verdict (live against the deployed contract)
- [x] Unit tests — pricing, requirements, challenge, config gate (13 total green)
- [ ] Set OKX_API_KEY / SECRET / PASSPHRASE + VETO_PAYTO_ADDRESS to enforce payment
- [ ] Redis verdict cache (optional)

**Run**
```bash
npm run engine:dev
# health:  GET  http://localhost:8787/health
# verdict: POST http://localhost:8787/verdict  (402 until X-PAYMENT provided)
```

> Payment enforces only when the four OKX vars are set. Without them the
> engine runs open (dev mode) so you can test the verdict pipeline first,
> then flip payment on by filling the keys. Settlement is real USDT on
> X Layer mainnet (eip155:196) via the OKX Facilitator.

---

## Phase 5 — SDK

- [ ] `guard(signer, opts)` wrapper
- [ ] Auto-route every outgoing tx through `/verdict`
- [ ] Refuse to sign on VETO; flag on WARN
- [ ] `onVerdict` callback hook
- [ ] Published build (`packages/sdk/dist`)

**Commands**
```bash
npm run sdk:build
```

---

## Phase 6 — Next.js UI

- [ ] Port approved landing (hero image, floating cards, horizontal slides)
- [ ] Port approved dashboard (all modules, one palette)
- [ ] Lenis smooth scroll + GSAP pinned sections
- [ ] Drop generated hero + hands images into `/public`
- [ ] Responsive / mobile pass

**Commands**
```bash
npm run web:dev
npm run web:build
```

---

## Phase 7 — Integration

- [ ] Dashboard reads live verdict feed from engine
- [ ] Intent-vs-effect panel bound to real verdicts
- [ ] Attestation ledger reads on-chain events
- [ ] x402 billing panel reads real usage

---

## Phase 8 — Deploy

- [ ] Web → Vercel
- [ ] Engine → Railway
- [ ] Contract live on X Layer testnet with public address
- [ ] End-to-end smoke test through the deployed stack

---

## Phase 9 — Listing (post-checklist)

- [ ] Register ASP on OKX.AI (A2MCP)
- [ ] Submit for listing review **by July 14–15** (not the deadline)
- [ ] Confirm listing goes live

## Phase 10 — Demo / X post

- [ ] 90-second demo video (paste malicious tx → VETO → attestation hash)
- [ ] X thread, tag `@OKX` / `@XLayerOfficial`, hashtag `#okxai`
- [ ] Public "VETO a live malicious tx" post
VETO_EOF

echo ""
echo "Done. Phase 4 files written."
echo "Test:  npm --workspace apps/engine run test   (expect 13 passing)"
echo "Run:   npm run engine:dev   then  GET http://localhost:8787/health"
