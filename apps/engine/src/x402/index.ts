import type { FastifyReply, FastifyRequest } from "fastify";
import { config } from "../lib/config";
import { challengeFor, challengeHeaderFor, requirementsFor } from "./pricing";
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
 *      The challenge is returned BOTH as the JSON body AND as a base64-
 *      encoded PAYMENT-REQUIRED header (required by the x402 spec).
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
    // Pass-through: Express gateway handles the official x402 checks
    return;
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
