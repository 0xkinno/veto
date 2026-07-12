// Load .env BEFORE anything reads process.env — config.ts resolves its values
// at module-load time, so this import must come first.
import "dotenv/config";

import Fastify from "fastify";
import { config } from "./lib/config";
import { registerRoutes } from "./routes";
import { hydrateRegistries, drainerCount } from "./lib/registries";
import { paymentConfigured as paymentReady } from "./x402/facilitator";

async function main() {
  const app = Fastify({ logger: true });

  // Load the drainer set (seed + any live feed) before serving.
  await hydrateRegistries();

  await app.register(import("@fastify/cors"), { origin: true });
  await registerRoutes(app);

  try {
    await app.listen({ port: config.port, host: "0.0.0.0" });

    // Say out loud what we actually resolved. A silent fallback to the wrong
    // chain is how you end up grading a live contract as an empty wallet.
    app.log.info(`VETO engine listening on :${config.port}`);
    app.log.info("");
    app.log.info(`  SIMULATE on   chain ${config.chainId}  ${config.rpcUrl}`);
    app.log.info(`                (must be the chain the calling agent transacts on)`);
    app.log.info(
      `  ATTEST   to   ${config.attestationAddress || "NOT SET — verdicts will NOT be attested"}`
    );
    app.log.info(`                ${config.attestationRpcUrl}`);
    app.log.info(
      `                attester ${config.attesterKey ? "configured" : "NOT SET — verdicts will NOT be attested"}`
    );
    app.log.info(
      `  PAID     in   USDT on ${config.x402.network} -> ${
        config.x402.payTo || "NO PAYOUT ADDRESS SET"
      }`
    );
    app.log.info(
      `  x402:         ${
        paymentReady()
          ? "ENFORCED — callers must pay"
          : "DEV MODE (OPEN) — set OKX_API_KEY, OKX_API_SECRET, OKX_API_PASSPHRASE and VETO_PAYTO_ADDRESS to charge"
      }`
    );
    app.log.info(`  Drainer set:  ${drainerCount()} addresses`);
    app.log.info("");
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

main();
