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
