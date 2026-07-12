// Load .env BEFORE anything reads process.env — config.ts resolves its values
// at module-load time, so this import must come first.
import "dotenv/config";

import Fastify from "fastify";
import { config } from "./lib/config";
import { registerRoutes } from "./routes";

async function main() {
  const app = Fastify({ logger: true });

  await app.register(import("@fastify/cors"), { origin: true });
  await registerRoutes(app);

  try {
    await app.listen({ port: config.port, host: "0.0.0.0" });

    // Say out loud what we actually resolved. A silent fallback to the wrong
    // chain is how you end up grading a live contract as an empty wallet.
    app.log.info(`VETO engine listening on :${config.port}`);
    app.log.info(`RPC:         ${config.rpcUrl}`);
    app.log.info(
      `Attestation: ${config.attestationAddress || "NOT SET — verdicts will not be attested on-chain"}`
    );
    app.log.info(
      `Attester:    ${config.attesterKey ? "configured" : "NOT SET — verdicts will not be attested on-chain"}`
    );
    app.log.info(
      `x402:        ${
        config.x402.apiKey && config.x402.payTo
          ? "enabled (payment enforced)"
          : "dev mode (open — set OKX keys + VETO_PAYTO_ADDRESS to enforce)"
      }`
    );
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

main();
