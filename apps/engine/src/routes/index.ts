import type { FastifyInstance } from "fastify";
import { requirePayment, type PaidRequest } from "../x402";
import { runVerdict } from "./verdict-core";
import { recent, stats } from "../lib/store";
import { scanApprovals } from "../instruments/approvals";
import { checkCounterparty } from "../instruments/counterparty";
import { screenPayload } from "../instruments/payload";
import { runForensics } from "../instruments/forensics";
import type { PolicyId, VerdictRequest } from "../lib/types";

/**
 * The five instruments. One engine — simulate, diff, prove — pointed at five
 * different decisions. Every endpoint is gated by x402 pay-per-call.
 *
 *   /verdict       is this exact transaction safe to sign, right now?
 *   /approvals     which live allowances expose this wallet to a drain?
 *   /payload       is this inbound job trying to inject or drain?
 *   /counterparty  can this address be trusted before I engage?
 *   /forensics     what should have been caught in this historical tx?
 *
 * Read endpoints (/stats, /verdicts) and the free /demo/* routes power the
 * dashboard and the public console.
 */
export async function registerRoutes(app: FastifyInstance) {
  app.get("/health", async () => ({ status: "ok", service: "veto-engine" }));

  // ---- live dashboard reads --------------------------------------------
  app.get("/stats", async () => stats());
  app.get("/verdicts", async (request) => {
    const q = request.query as { limit?: string };
    return { verdicts: recent(q.limit ? Number(q.limit) : 12) };
  });

  // ---- 1. /verdict — pre-signature verdicts ----------------------------
  app.route({
    method: ["GET", "POST"],
    url: "/verdict",
    preHandler: requirePayment("verdict"),
    handler: async (request) => {
      if (request.method === "GET") {
        return { status: "ready", service: "verdict" };
      }
      const body = request.body as VerdictRequest;
      const payment = (request as PaidRequest).payment;
      return runVerdict(body, payment?.txHash);
    }
  });

  // ---- 2. /approvals — approval hygiene --------------------------------
  app.route({
    method: ["GET", "POST"],
    url: "/approvals",
    preHandler: requirePayment("approvals"),
    handler: async (request) => {
      if (request.method === "GET") {
        return { status: "ready", service: "approvals" };
      }
      const { wallet } = request.body as { wallet: string };
      if (!wallet) return { error: "wallet is required" };
      return scanApprovals(wallet);
    }
  });

  // ---- 3. /payload — task-payload screening ----------------------------
  app.route({
    method: ["GET", "POST"],
    url: "/payload",
    preHandler: requirePayment("payload"),
    handler: async (request) => {
      if (request.method === "GET") {
        return { status: "ready", service: "payload" };
      }
      const { payload } = request.body as { payload: unknown };
      if (payload == null) return { error: "payload is required" };
      return screenPayload(payload);
    }
  });

  // ---- 4. /counterparty — counterparty pre-check -----------------------
  app.route({
    method: ["GET", "POST"],
    url: "/counterparty",
    preHandler: requirePayment("counterparty"),
    handler: async (request) => {
      if (request.method === "GET") {
        return { status: "ready", service: "counterparty" };
      }
      const { address } = request.body as { address: string };
      if (!address) return { error: "address is required" };
      return checkCounterparty(address);
    }
  });

  // ---- 5. /forensics — post-incident forensics -------------------------
  app.route({
    method: ["GET", "POST"],
    url: "/forensics",
    preHandler: requirePayment("forensics"),
    handler: async (request) => {
      if (request.method === "GET") {
        return { status: "ready", service: "forensics" };
      }
      const { txHash, policy, intent } = request.body as {
        txHash: string;
        policy?: PolicyId;
        intent?: string;
      };
      if (!txHash) return { error: "txHash is required" };
      return runForensics(txHash, policy ?? "standard", intent);
    }
  });

  // ---- free demo routes (unpaid) — the public console ------------------
  app.post("/demo/verdict", async (request) => {
    const body = request.body as VerdictRequest;
    return runVerdict(body, undefined, true);
  });

  app.post("/demo/approvals", async (request) => {
    const { wallet } = request.body as { wallet: string };
    if (!wallet) return { error: "wallet is required" };
    return scanApprovals(wallet);
  });

  app.post("/demo/payload", async (request) => {
    const { payload } = request.body as { payload: unknown };
    if (payload == null) return { error: "payload is required" };
    return screenPayload(payload);
  });

  app.post("/demo/counterparty", async (request) => {
    const { address } = request.body as { address: string };
    if (!address) return { error: "address is required" };
    return checkCounterparty(address);
  });

  app.post("/demo/forensics", async (request) => {
    const { txHash, policy, intent } = request.body as {
      txHash: string;
      policy?: PolicyId;
      intent?: string;
    };
    if (!txHash) return { error: "txHash is required" };
    return runForensics(txHash, policy ?? "standard", intent);
  });
}
