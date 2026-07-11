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
