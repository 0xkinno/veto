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
