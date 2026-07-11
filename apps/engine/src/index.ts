import Fastify from "fastify";
import { config } from "./lib/config";
import { registerRoutes } from "./routes";

async function main() {
  const app = Fastify({ logger: true });

  await app.register(import("@fastify/cors"), { origin: true });
  await registerRoutes(app);

  try {
    await app.listen({ port: config.port, host: "0.0.0.0" });
    app.log.info(`VETO engine listening on :${config.port} (chain ${config.chainId})`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

main();
