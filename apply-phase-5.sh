#!/usr/bin/env bash
# VETO — Phase 5 apply script (SDK: guard + check + x402 payment)
# Run from the root of your veto folder:  bash apply-phase-5.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 5 files into $(pwd) ..."
mkdir -p packages/sdk/src packages/sdk/src/__tests__

# ---------- packages/sdk/src/index.ts ----------
cat > packages/sdk/src/index.ts << 'VETO_EOF'
/**
 * @veto/sdk
 *
 * Route every agent transaction through VETO before it is signed.
 *
 *   import { guard } from "@veto/sdk";
 *   const signer = guard(agentSigner, { policy: "treasury-strict" });
 *   await signer.sendTransaction(tx);   // a VETO verdict refuses to sign
 *
 * Two entry points:
 *   - guard(signer, opts)  → a drop-in wrapper; VETO on every send.
 *   - check(tx, opts)      → a one-shot verdict without wrapping a signer.
 *
 * The SDK speaks the engine's HTTP API and handles x402 payment: when the
 * engine answers 402, the SDK asks the caller's paySettle hook to produce
 * an X-PAYMENT header, then retries once.
 */

export type Verdict = "ALLOW" | "WARN" | "VETO";
export type PolicyId = "treasury-strict" | "standard" | "degen-loose";

export interface VerdictResult {
  verdict: Verdict;
  reasons: string[];
  findings?: unknown[];
  evidenceHash: string;
  attestationTx?: string;
  blockNumber?: number;
  latencyMs?: number;
  policy?: PolicyId;
}

/** The x402 challenge the engine returns on 402. */
export interface PaymentChallenge {
  x402Version: number;
  accepts: Array<{
    scheme: string;
    network: string;
    amount: string;
    asset: string;
    payTo: string;
    maxTimeoutSeconds?: number;
    extra?: Record<string, unknown>;
  }>;
  resource?: { url: string };
  error?: string;
}

/**
 * Produces the base64 X-PAYMENT header for a challenge. Supplied by the
 * caller (their agent wallet / OKX payment SDK signs the authorization).
 * Return null to decline payment (the verdict call then fails).
 */
export type PaySettle = (
  challenge: PaymentChallenge
) => Promise<string | null>;

export interface GuardOptions {
  /** VETO engine base URL. */
  endpoint?: string;
  /** Risk posture applied to every verdict. */
  policy?: PolicyId;
  /** Natural-language intent, or a function deriving it per tx. */
  intent?: string | ((tx: TxLike) => string);
  /** Chain id declared to the engine (X Layer = 196). */
  chainId?: number;
  /** Fired on every verdict, ALLOW included. */
  onVerdict?: (v: VerdictResult) => void;
  /** If true, WARN also refuses to sign (default false — WARN signs). */
  strictWarn?: boolean;
  /** Produces the X-PAYMENT header when the engine returns 402. */
  paySettle?: PaySettle;
}

export interface TxLike {
  to?: string;
  data?: string;
  value?: bigint | string | number;
  [k: string]: unknown;
}

/** Minimal signer surface VETO needs to wrap (ethers v6 compatible). */
export interface MinimalSigner {
  getAddress(): Promise<string>;
  sendTransaction(tx: TxLike): Promise<unknown>;
}

export class VetoRefused extends Error {
  constructor(public result: VerdictResult) {
    super(`VETO — ${result.reasons.join("; ") || "signature refused"}`);
    this.name = "VetoRefused";
  }
}

export class VetoPaymentRequired extends Error {
  constructor(public challenge: PaymentChallenge) {
    super("VETO — payment required and no paySettle handler provided");
    this.name = "VetoPaymentRequired";
  }
}

const DEFAULT_ENDPOINT = "http://localhost:8787";
const DEFAULT_CHAIN = 196;

/** One-shot verdict for a transaction without wrapping a signer. */
export async function check(
  tx: TxLike,
  from: string,
  opts: GuardOptions = {}
): Promise<VerdictResult> {
  const endpoint = opts.endpoint ?? DEFAULT_ENDPOINT;
  const policy = opts.policy ?? "standard";
  const chainId = opts.chainId ?? DEFAULT_CHAIN;
  const summary =
    typeof opts.intent === "function"
      ? opts.intent(tx)
      : opts.intent ?? "unspecified";

  const body = JSON.stringify({
    tx: {
      from,
      to: tx.to,
      data: tx.data ?? "0x",
      value: tx.value != null ? String(tx.value) : undefined,
      chainId,
    },
    intent: { summary },
    policy,
  });

  const result = await postVerdict(`${endpoint}/verdict`, body, opts.paySettle);
  opts.onVerdict?.(result);
  return result;
}

/**
 * Wrap a signer so every sendTransaction is ruled on by VETO first.
 * VETO refuses to sign; WARN signs unless strictWarn is set.
 */
export function guard<T extends MinimalSigner>(
  signer: T,
  opts: GuardOptions = {}
): T {
  const wrappedSend = async (tx: TxLike) => {
    const from = await signer.getAddress();
    const result = await check(tx, from, opts);

    if (result.verdict === "VETO") throw new VetoRefused(result);
    if (result.verdict === "WARN" && opts.strictWarn) {
      throw new VetoRefused(result);
    }
    return signer.sendTransaction(tx);
  };

  return new Proxy(signer, {
    get(target, prop, receiver) {
      if (prop === "sendTransaction") return wrappedSend;
      return Reflect.get(target, prop, receiver);
    },
  }) as T;
}

// ---- internal ---------------------------------------------------------

async function postVerdict(
  url: string,
  body: string,
  paySettle?: PaySettle,
  retried = false
): Promise<VerdictResult> {
  const headers: Record<string, string> = {
    "content-type": "application/json",
  };

  const res = await fetch(url, { method: "POST", headers, body });

  // Payment required — pay once and retry.
  if (res.status === 402) {
    const challenge = (await res.json()) as PaymentChallenge;
    if (retried || !paySettle) throw new VetoPaymentRequired(challenge);
    const xPayment = await paySettle(challenge);
    if (!xPayment) throw new VetoPaymentRequired(challenge);
    return postVerdictPaid(url, body, xPayment, paySettle);
  }

  if (!res.ok) {
    throw new Error(`VETO engine error ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) as VerdictResult;
}

async function postVerdictPaid(
  url: string,
  body: string,
  xPayment: string,
  paySettle: PaySettle
): Promise<VerdictResult> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", "x-payment": xPayment },
    body,
  });
  if (res.status === 402) {
    // Payment did not satisfy the gate; surface the challenge, no loop.
    throw new VetoPaymentRequired((await res.json()) as PaymentChallenge);
  }
  if (!res.ok) {
    throw new Error(`VETO engine error ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) as VerdictResult;
}
VETO_EOF

# ---------- packages/sdk/src/__tests__/sdk.test.ts ----------
cat > packages/sdk/src/__tests__/sdk.test.ts << 'VETO_EOF'
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { guard, check, VetoRefused, VetoPaymentRequired } from "../index";

const FROM = "0x1111111111111111111111111111111111111111";

function mockFetchOnce(status: number, json: unknown) {
  return vi.fn().mockResolvedValue({
    status,
    ok: status >= 200 && status < 300,
    json: async () => json,
    text: async () => JSON.stringify(json),
  });
}

const fakeSigner = {
  getAddress: async () => FROM,
  sendTransaction: vi.fn(async (tx: unknown) => ({ hash: "0xsent", tx })),
};

beforeEach(() => {
  fakeSigner.sendTransaction.mockClear();
});
afterEach(() => {
  vi.unstubAllGlobals();
});

describe("check()", () => {
  it("returns the verdict from the engine", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "ALLOW", reasons: [], evidenceHash: "0xabc",
    }));
    const r = await check({ to: "0x2", data: "0x" }, FROM);
    expect(r.verdict).toBe("ALLOW");
  });
});

describe("guard()", () => {
  it("signs when the verdict is ALLOW", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "ALLOW", reasons: [], evidenceHash: "0xabc",
    }));
    const s = guard(fakeSigner);
    await s.sendTransaction({ to: "0x2", data: "0x" });
    expect(fakeSigner.sendTransaction).toHaveBeenCalledOnce();
  });

  it("refuses to sign on VETO", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "VETO", reasons: ["undeclared transfer"], evidenceHash: "0xabc",
    }));
    const s = guard(fakeSigner);
    await expect(s.sendTransaction({ to: "0x2", data: "0x" })).rejects.toThrow(VetoRefused);
    expect(fakeSigner.sendTransaction).not.toHaveBeenCalled();
  });

  it("signs on WARN by default, refuses on strictWarn", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "WARN", reasons: ["slippage high"], evidenceHash: "0xabc",
    }));
    const lenient = guard(fakeSigner);
    await lenient.sendTransaction({ to: "0x2", data: "0x" });
    expect(fakeSigner.sendTransaction).toHaveBeenCalledOnce();

    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "WARN", reasons: ["slippage high"], evidenceHash: "0xabc",
    }));
    const strict = guard(fakeSigner, { strictWarn: true });
    await expect(strict.sendTransaction({ to: "0x2", data: "0x" })).rejects.toThrow(VetoRefused);
  });

  it("fires onVerdict for every ruling", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "ALLOW", reasons: [], evidenceHash: "0xabc",
    }));
    const seen: string[] = [];
    const s = guard(fakeSigner, { onVerdict: (v) => seen.push(v.verdict) });
    await s.sendTransaction({ to: "0x2", data: "0x" });
    expect(seen).toEqual(["ALLOW"]);
  });
});

describe("x402 payment", () => {
  it("throws VetoPaymentRequired when 402 and no paySettle", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(402, {
      x402Version: 2, accepts: [{ scheme: "exact", network: "eip155:196", amount: "150000", asset: "0x", payTo: "0x" }],
    }));
    await expect(check({ to: "0x2" }, FROM)).rejects.toThrow(VetoPaymentRequired);
  });

  it("pays via paySettle then retries and succeeds", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({
        status: 402, ok: false,
        json: async () => ({ x402Version: 2, accepts: [{ scheme: "exact", network: "eip155:196", amount: "150000", asset: "0x", payTo: "0x" }] }),
        text: async () => "",
      })
      .mockResolvedValueOnce({
        status: 200, ok: true,
        json: async () => ({ verdict: "ALLOW", reasons: [], evidenceHash: "0xabc" }),
        text: async () => "",
      });
    vi.stubGlobal("fetch", fetchMock);

    const paySettle = vi.fn(async () => "base64xpayment");
    const r = await check({ to: "0x2" }, FROM, { paySettle });
    expect(paySettle).toHaveBeenCalledOnce();
    expect(r.verdict).toBe("ALLOW");
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
VETO_EOF

# ---------- packages/sdk/package.json ----------
cat > packages/sdk/package.json << 'VETO_EOF'
{
  "name": "@veto/sdk",
  "version": "0.1.0",
  "description": "guard(signer) \u2014 route every agent transaction through VETO before it signs.",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "test": "vitest run"
  },
  "devDependencies": {
    "typescript": "^5.6.2",
    "vitest": "^2.1.1"
  },
  "license": "MIT"
}VETO_EOF

# ---------- packages/sdk/tsconfig.json ----------
cat > packages/sdk/tsconfig.json << 'VETO_EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "declaration": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "lib": ["ES2022", "DOM"]
  },
  "include": ["src"],
  "exclude": ["src/__tests__", "**/*.test.ts"]
}
VETO_EOF

# ---------- packages/sdk/README.md ----------
cat > packages/sdk/README.md << 'VETO_EOF'
# @veto/sdk

Route every agent transaction through VETO before it is signed. A VETO
verdict refuses to sign; a WARN signs but reports. Ten lines to integrate.

## Install

```bash
npm install @veto/sdk
```

## guard(signer)

Wrap any ethers v6 signer. Every `sendTransaction` is ruled on first.

```ts
import { guard } from "@veto/sdk";

const signer = guard(agentSigner, {
  endpoint: "https://engine.veto.dev",
  policy: "treasury-strict",
  intent: (tx) => `agent task: ${tx.to}`,
  onVerdict: (v) => audit.log(v),
});

// a red verdict refuses to sign — by design
await signer.sendTransaction(tx);
// throws VetoRefused — "undeclared unlimited approval"
```

## check(tx, from)

A one-shot verdict without wrapping a signer.

```ts
import { check } from "@veto/sdk";

const v = await check(tx, agentAddress, { policy: "standard" });
if (v.verdict === "VETO") abort(v.reasons);
```

## Options

| Option       | Description                                                    |
| ------------ | -------------------------------------------------------------- |
| `endpoint`   | VETO engine base URL (default `http://localhost:8787`)         |
| `policy`     | `treasury-strict` \| `standard` \| `degen-loose`               |
| `intent`     | Natural-language intent, or a function `(tx) => string`        |
| `chainId`    | Chain declared to the engine (default `196`, X Layer)          |
| `strictWarn` | If true, WARN also refuses to sign (default false)             |
| `onVerdict`  | Fired on every verdict, ALLOW included                         |
| `paySettle`  | Produces the `X-PAYMENT` header when the engine returns 402    |

## Payment

When the engine enforces x402, a verdict call returns HTTP 402 with a
payment challenge. Supply `paySettle` to sign the payment authorization
(via your agent wallet / OKX payment SDK) and the SDK retries once:

```ts
const signer = guard(agentSigner, {
  paySettle: async (challenge) => wallet.signX402(challenge), // → base64 header
});
```

Without `paySettle`, a 402 throws `VetoPaymentRequired` carrying the challenge.

## Errors

- `VetoRefused` — the verdict was VETO (or WARN under `strictWarn`). Carries `.result`.
- `VetoPaymentRequired` — payment needed and unpaid. Carries `.challenge`.
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
echo "Done. Phase 5 files written."
echo "Install (adds vitest):  npm install"
echo "Test:   npm --workspace packages/sdk run test   (expect 7 passing)"
echo "Build:  npm run sdk:build"
