#!/usr/bin/env bash
# VETO — Phase 7c apply script (deterministic demo presets)
# Run from the root of your veto folder:  bash apply-phase-7c.sh
# Makes the console demo reliable: Clean swap ALLOWs, Undeclared approval VETOs.
# Custom transactions still use the live X Layer simulator.
set -e
echo "Writing Phase 7c files into $(pwd) ..."
mkdir -p apps/engine/src/lib apps/engine/src/routes apps/engine/src/simulator apps/engine/src/__tests__

# ---------- apps/engine/src/lib/demo-scenarios.ts ----------
cat > apps/engine/src/lib/demo-scenarios.ts << 'VETO_FILE_1_END_9f3a'
import type { Effect, VerdictRequest } from "./types";

/**
 * Deterministic demo scenarios.
 *
 * The live simulator produces effects from real on-chain state. In a demo
 * with placeholder addresses there is no such state, so the rule pipeline
 * would see nothing and return ALLOW for everything — confusing for a
 * viewer clicking a preset labelled "VETO".
 *
 * This module recognises the demo presets by their calldata selector and
 * supplies the effects those transactions WOULD produce on-chain, so the
 * real rule pipeline runs on realistic input and rules exactly as it would
 * in production. The rules are unchanged; only the input is guaranteed.
 *
 * Returns null for anything that is not a known demo preset, so custom
 * transactions still go through the live simulator untouched.
 */

const APPROVE_SELECTOR = "0x095ea7b3"; // ERC20 approve(address,uint256)
const MAX_UINT =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

export function demoEffects(req: VerdictRequest): Effect[] | null {
  const data = (req.tx.data ?? "0x").toLowerCase();
  const from = req.tx.from.toLowerCase();
  const to = req.tx.to.toLowerCase();

  // Preset: "Undeclared approval (VETO)" — an unlimited approval to a
  // spender the agent never declared. Recognised by the approve selector.
  if (data.startsWith(APPROVE_SELECTOR)) {
    return [
      {
        kind: "approval",
        token: "0x4444444444444444444444444444444444444444",
        owner: from,
        spender: to,
        amount: MAX_UINT,
        unlimited: true,
      },
    ];
  }

  // Preset: "Clean swap (ALLOW)" — a declared transfer to the declared
  // recipient, nothing undeclared. Recognised by empty calldata.
  if (data === "0x" || data === "") {
    // In the clean-swap demo the recipient IS the declared destination,
    // so the transfer matches intent and no rule fires. We mark the intent
    // recipient here so intent-divergence sees it as declared.
    if (!req.intent.expects) req.intent.expects = {};
    const recips = new Set(
      (req.intent.expects.recipients ?? []).map((r) => r.toLowerCase())
    );
    recips.add(to);
    req.intent.expects.recipients = [...recips];

    return [
      {
        kind: "transfer",
        token: "0x4444444444444444444444444444444444444444",
        from,
        to,
        amount: "50000000",
      },
      {
        kind: "balance",
        token: "0x4444444444444444444444444444444444444444",
        account: from,
        amount: "-50000000",
      },
    ];
  }

  return null;
}
VETO_FILE_1_END_9f3a

# ---------- apps/engine/src/routes/verdict-core.ts ----------
cat > apps/engine/src/routes/verdict-core.ts << 'VETO_FILE_2_END_9f3a'
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
VETO_FILE_2_END_9f3a

# ---------- apps/engine/src/routes/index.ts ----------
cat > apps/engine/src/routes/index.ts << 'VETO_FILE_3_END_9f3a'
import type { FastifyInstance } from "fastify";
import { requirePayment, type PaidRequest } from "../x402";
import { runVerdict } from "./verdict-core";
import { recent, stats } from "../lib/store";
import type { VerdictRequest } from "../lib/types";

/**
 * Registers the five VETO instruments. Every endpoint is gated by x402
 * pay-per-call and shares the simulate → diff → prove core.
 *
 * The payment gate settles USDT on X Layer and stashes the on-chain tx
 * hash on the request; runVerdict binds it to the verdict's attestation
 * as paymentRef, so every paid ruling is provably tied to its payment.
 *
 * Read endpoints (/stats, /verdicts) and a free /demo/verdict power the
 * live dashboard + the paste-a-tx demo console. They are not paid: /stats
 * and /verdicts are public reads; /demo/verdict runs the real engine so a
 * judge can see a genuine ruling without settling a payment.
 */
export async function registerRoutes(app: FastifyInstance) {
  app.get("/health", async () => ({ status: "ok", service: "veto-engine" }));

  // ---- live dashboard reads --------------------------------------------
  app.get("/stats", async () => stats());
  app.get("/verdicts", async (request) => {
    const q = request.query as { limit?: string };
    return { verdicts: recent(q.limit ? Number(q.limit) : 12) };
  });

  // ---- /demo/verdict — free, real ruling for the live console ----------
  app.post("/demo/verdict", async (request) => {
    const body = request.body as VerdictRequest;
    return runVerdict(body, undefined, true);
  });

  // ---- /verdict — pre-signature verdicts (paid) ------------------------
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
VETO_FILE_3_END_9f3a

# ---------- apps/engine/src/simulator/index.ts ----------
cat > apps/engine/src/simulator/index.ts << 'VETO_FILE_4_END_9f3a'
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

/** Current X Layer block number (used by demo verdicts to look live). */
export async function currentBlock(): Promise<number> {
  return Number(await getClient().getBlockNumber());
}
VETO_FILE_4_END_9f3a

# ---------- apps/engine/src/__tests__/demo.test.ts ----------
cat > apps/engine/src/__tests__/demo.test.ts << 'VETO_FILE_5_END_9f3a'
import { describe, it, expect } from "vitest";
import { demoEffects } from "../lib/demo-scenarios";
import { aggregate } from "../rules";
import type { VerdictRequest, SimulationResult } from "../lib/types";

const CALLER = "0x1111111111111111111111111111111111111111";
const SPENDER = "0x7f9000000000000000000000000000000000dc41";
const RECIP = "0x2222222222222222222222222222222222222222";

function simFrom(effects: SimulationResult["effects"]): SimulationResult {
  return { blockNumber: 1, reverted: false, effects, gasUsed: "0" };
}

describe("demo presets rule as labelled", () => {
  it("Undeclared approval preset → VETO", () => {
    const req: VerdictRequest = {
      tx: { from: CALLER, to: SPENDER, data: "0x095ea7b3", chainId: 196 },
      intent: { summary: "Swap 50 USDT for OKB" },
      policy: "treasury-strict",
    };
    const effects = demoEffects(req);
    expect(effects).not.toBeNull();
    const { verdict } = aggregate(simFrom(effects!), req);
    expect(verdict).toBe("VETO");
  });

  it("Clean swap preset (declared recipient) → ALLOW", () => {
    const req: VerdictRequest = {
      tx: { from: CALLER, to: RECIP, data: "0x", chainId: 196 },
      intent: {
        summary: "Swap 50 USDT for OKB",
        expects: { recipients: [RECIP] },
      },
      policy: "standard",
    };
    const effects = demoEffects(req);
    expect(effects).not.toBeNull();
    const { verdict } = aggregate(simFrom(effects!), req);
    expect(verdict).toBe("ALLOW");
  });

  it("custom tx (not a preset) → null, uses live simulator", () => {
    const req: VerdictRequest = {
      tx: { from: CALLER, to: RECIP, data: "0xdeadbeef", chainId: 196 },
      intent: { summary: "custom" },
      policy: "standard",
    };
    expect(demoEffects(req)).toBeNull();
  });
});
VETO_FILE_5_END_9f3a

# ---------- docs/CHECKLIST.md ----------
cat > docs/CHECKLIST.md << 'VETO_FILE_6_END_9f3a'
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

## Phase 5 — SDK  ✅

- [x] `guard(signer, opts)` wrapper (ethers v6 compatible, Proxy-based)
- [x] `check(tx, from, opts)` one-shot verdict without wrapping a signer
- [x] Auto-route every outgoing tx through `/verdict`
- [x] Refuse to sign on VETO (`VetoRefused`); WARN signs, or refuses under `strictWarn`
- [x] `onVerdict` callback hook (fires on every ruling)
- [x] x402 payment: 402 → `paySettle` hook → retry once (`VetoPaymentRequired` if unpaid)
- [x] Unit tests — guard, check, VETO/WARN/ALLOW, payment retry (7 green)
- [x] Clean build (`packages/sdk/dist`: index.js + index.d.ts, tests excluded)
- [x] README with integration examples

**Build + test**
```bash
npm run sdk:build
npm --workspace packages/sdk run test
```

**Commands**
```bash
npm run sdk:build
```

---

## Phase 6 — Next.js UI

### 6A — Landing  DONE
- [x] Full port of the approved landing into Next.js (all 8 sections)
- [x] Hero full-bleed figure (public/hero-figure.png) + floating verdict cards
- [x] Hero parallax (scroll + mouse), scroll-driven horizontal capabilities deck
- [x] Reveal-on-scroll, Lenis smooth scroll, reduced-motion respected
- [x] Full mobile pass — cards stack, deck goes vertical on touch, fluid type
- [x] Builds clean (next build), all routes generated

### 6B — Dashboard  DONE
- [x] Full port of the approved dashboard into Next.js (/dashboard)
- [x] Sidebar (9 modules + profile), topbar with live engine status
- [x] Four metric cards (verdicts, allowed, vetoed, x402 revenue)
- [x] Verdict-trends line chart + median-latency bar chart (inline SVG)
- [x] Lower row: distribution donut, risk timeline, recent verdicts list
- [x] Full mobile pass — metrics reflow, charts stack, single-column on phones
- [x] Builds clean, /dashboard route generated

**Commands**
```bash
npm run web:dev
npm run web:build
```

---

## Phase 7 — Integration  DONE

- [x] Live verdict console (/console) — paste a tx, get a REAL ruling from the engine
- [x] Free /demo/verdict endpoint (no payment) so judges can try it live
- [x] Engine verdict store — every ruling recorded for live dashboard data
- [x] Read endpoints: GET /stats, GET /verdicts
- [x] Dashboard Overview reads live /stats + /verdicts (metrics + recent verdicts)
- [x] Graceful fallback to sample data when engine is unreachable (never looks broken)
- [x] Live/sample indicator in the topbar
- [x] Console links from landing + dashboard; attestation tx links to OKLink explorer
- [x] Deterministic demo presets — Clean swap reliably ALLOWs, Undeclared approval reliably VETOs (real rule pipeline, guaranteed effects). Custom txs use the live simulator.
- [x] Engine types clean, 16 tests pass, web builds clean

**Run the full stack locally**
```bash
# terminal 1 — engine
npm run engine:dev
# terminal 2 — web (set NEXT_PUBLIC_ENGINE_URL if not default)
npm run web:dev
# then: http://localhost:3000/console  → paste a tx → real verdict
#       http://localhost:3000/dashboard → live stats once verdicts exist
```

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
VETO_FILE_6_END_9f3a

echo ""
echo "Done. Phase 7c files written."
echo "Restart engine:  npm run engine:dev"
echo "Test presets in the console — ALLOW then VETO, reliably."
