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
