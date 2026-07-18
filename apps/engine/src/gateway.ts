// OKX official x402 gateway -- single entry process.
//
// This process:
//   1. Spawns the Fastify verdict engine (dist/index.js) as a child,
//      bound to INTERNAL_PORT and never public.
//   2. Waits until the engine's /health responds.
//   3. Listens on the public PORT with OKX's official x402 middleware
//      gating the paid routes, and proxies everything else to the engine.
//
// One `node dist/gateway.js` boots the whole system. No shell &, no race.
import "dotenv/config";

import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import http from "node:http";

import express from "express";
import { createProxyMiddleware } from "http-proxy-middleware";
import { handleMcpRequest } from "./mcp.js";
import {
  paymentMiddleware,
  x402ResourceServer,
} from "@okxweb3/x402-express";
import { ExactEvmScheme } from "@okxweb3/x402-evm/exact/server";
import { OKXFacilitatorClient } from "@okxweb3/x402-core";
import fs from "node:fs";
import { Wallet, JsonRpcProvider, formatEther } from "ethers";

const PUBLIC_PORT = Number(process.env.PORT ?? 8787);
const INTERNAL_PORT = Number(process.env.INTERNAL_PORT ?? 8788);
const NETWORK = "eip155:196";
const PAY_TO = process.env.VETO_PAYTO_ADDRESS ?? "";

const OKX_API_KEY = process.env.OKX_API_KEY ?? "";
const OKX_SECRET_KEY =
  process.env.OKX_SECRET_KEY ?? process.env.OKX_API_SECRET ?? "";
const OKX_PASSPHRASE =
  process.env.OKX_PASSPHRASE ?? process.env.OKX_API_PASSPHRASE ?? "";

const paymentConfigured = Boolean(
  OKX_API_KEY && OKX_SECRET_KEY && OKX_PASSPHRASE && PAY_TO
);

// ---- 0. setup file logging ---------------------------------------------
const here = path.dirname(fileURLToPath(import.meta.url));
const logFile = path.join(here, "server.log");
fs.writeFileSync(logFile, ""); // truncate

function logToFile(msg: string) {
  const time = new Date().toISOString();
  try {
    fs.appendFileSync(logFile, `[${time}] ${msg}\n`);
  } catch (err) {
    // ignore logging errors
  }
}

const originalLog = console.log;
const originalError = console.error;
const originalWarn = console.warn;

console.log = (...args) => {
  logToFile(args.join(" "));
  originalLog(...args);
};
console.error = (...args) => {
  logToFile("[ERROR] " + args.join(" "));
  originalError(...args);
};
console.warn = (...args) => {
  logToFile("[WARN] " + args.join(" "));
  originalWarn(...args);
};

// ---- 1. spawn the Fastify engine on the internal port ------------------
const enginePath = path.join(here, "index.js");

const engine = spawn(process.execPath, [enginePath], {
  env: { ...process.env, PORT: String(INTERNAL_PORT), INTERNAL_PORT: String(INTERNAL_PORT) },
  stdio: "pipe",
});

engine.stdout.on("data", (data) => {
  logToFile("[ENGINE] " + data.toString().trim());
  process.stdout.write(data);
});

engine.stderr.on("data", (data) => {
  logToFile("[ENGINE-ERROR] " + data.toString().trim());
  process.stderr.write(data);
});

engine.on("exit", (code) => {
  console.error(`[gateway] engine process exited with code ${code}; shutting down`);
  process.exit(code ?? 1);
});

// ---- 2. wait for the engine to be healthy ------------------------------
function waitForEngine(retries = 60): Promise<void> {
  return new Promise((resolve, reject) => {
    const attempt = (n: number) => {
      const req = http.get(
        { host: "127.0.0.1", port: INTERNAL_PORT, path: "/health", timeout: 1000 },
        (res) => {
          res.resume();
          if (res.statusCode === 200) return resolve();
          retry(n);
        }
      );
      req.on("error", () => retry(n));
      req.on("timeout", () => {
        req.destroy();
        retry(n);
      });
    };
    const retry = (n: number) => {
      if (n <= 0) return reject(new Error("engine did not become healthy"));
      setTimeout(() => attempt(n - 1), 500);
    };
    attempt(retries);
  });
}

// ---- 3. start the public gateway ---------------------------------------
async function startGateway() {
  await waitForEngine();
  console.log(`[gateway] engine healthy on :${INTERNAL_PORT}`);

  const app = express();
  app.set("trust proxy", true);

  app.use((_req, res, next) => {
    res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate");
    next();
  });

  // A2MCP endpoint. OKX's marketplace bot connects here as an MCP client,
  // lists the five VETO tools, calls one, and gets a result. JSON body is
  // parsed only for this route so it does not interfere with the proxy.
  app.post("/mcp", express.json(), handleMcpRequest);
  // Some MCP clients open a GET for the SSE stream and a DELETE to end a
  // session. Handling all three makes /mcp work with any compliant client.
  app.get("/mcp", handleMcpRequest);
  app.delete("/mcp", handleMcpRequest);

  // Free health check for UptimeRobot + OKX reachability. Answered by the
  // gateway itself so it responds even before proxying is ready.
  app.get("/health", (_req, res) => {
    res.json({ status: "ok", service: "veto-engine" });
  });

  app.get("/", (_req, res) => {
    res.json({ status: "ok", service: "veto-engine", agent: "VETO" });
  });

  app.get("/debug-env", async (_req, res) => {
    const mask = (s?: string) => s ? `${s.slice(0, 3)}...${s.slice(-3)}` : "MISSING";
    let attesterAddress = "UNKNOWN";
    let attesterBalance = "0";
    try {
      if (process.env.ATTESTER_PRIVATE_KEY) {
        const provider = new JsonRpcProvider("https://rpc.xlayer.tech");
        const wallet = new Wallet(process.env.ATTESTER_PRIVATE_KEY, provider);
        attesterAddress = wallet.address;
        const bal = await provider.getBalance(wallet.address);
        attesterBalance = formatEther(bal);
      }
    } catch (err) {
      attesterAddress = "ERROR: " + String(err);
    }
    res.json({
      OKX_API_KEY: mask(OKX_API_KEY),
      OKX_SECRET_KEY: mask(OKX_SECRET_KEY),
      OKX_PASSPHRASE: mask(OKX_PASSPHRASE),
      VETO_PAYTO_ADDRESS: PAY_TO || "MISSING",
      ATTESTATION_ADDRESS: process.env.ATTESTATION_ADDRESS || "MISSING",
      ATTESTER_ADDRESS: attesterAddress,
      ATTESTER_BALANCE: attesterBalance,
      paymentConfigured,
    });
  });

  app.get("/debug-logs", (_req, res) => {
    if (!fs.existsSync(logFile)) return res.send("No logs yet.");
    res.type("text/plain").send(fs.readFileSync(logFile, "utf8"));
  });

  if (paymentConfigured) {
    const facilitatorClient = new OKXFacilitatorClient({
      apiKey: OKX_API_KEY,
      secretKey: OKX_SECRET_KEY,
      passphrase: OKX_PASSPHRASE,
    });

    const resourceServer = new x402ResourceServer(facilitatorClient);
    resourceServer.register(NETWORK, new ExactEvmScheme());

    app.use(
      paymentMiddleware(
        {
          "POST /verdict": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.15" }],
            description: "VETO pre-signature verdict",
            mimeType: "application/json",
          },
          "GET /verdict": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.15" }],
            description: "VETO pre-signature verdict",
            mimeType: "application/json",
          },
          "POST /counterparty": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.10" }],
            description: "VETO counterparty check",
            mimeType: "application/json",
          },
          "GET /counterparty": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.10" }],
            description: "VETO counterparty check",
            mimeType: "application/json",
          },
          "POST /payload": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.20" }],
            description: "VETO task-payload screening",
            mimeType: "application/json",
          },
          "GET /payload": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.20" }],
            description: "VETO task-payload screening",
            mimeType: "application/json",
          },
          "POST /approvals": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.30" }],
            description: "VETO approval hygiene",
            mimeType: "application/json",
          },
          "GET /approvals": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.30" }],
            description: "VETO approval hygiene",
            mimeType: "application/json",
          },
          "POST /forensics": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.50" }],
            description: "VETO post-incident forensics",
            mimeType: "application/json",
          },
          "GET /forensics": {
            accepts: [{ scheme: "exact", network: NETWORK, payTo: PAY_TO, price: "$0.50" }],
            description: "VETO post-incident forensics",
            mimeType: "application/json",
          },
        },
        resourceServer,
      ),
    );
    console.log("[gateway] x402 ENFORCED via OKX official SDK -> payTo", PAY_TO);
  } else {
    console.warn(
      "[gateway] x402 NOT configured (missing OKX_API_KEY / OKX_SECRET_KEY / OKX_PASSPHRASE / VETO_PAYTO_ADDRESS) -- proxying without payment"
    );
  }

  // Everything that passes the gate proxies to the internal Fastify engine.
  app.use(
    createProxyMiddleware({
      target: `http://127.0.0.1:${INTERNAL_PORT}`,
      changeOrigin: false,
      xfwd: true,
    })
  );

  app.listen(PUBLIC_PORT, "0.0.0.0", () => {
    console.log(`[gateway] VETO public gateway on :${PUBLIC_PORT} -> engine :${INTERNAL_PORT}`);
  });
}

startGateway().catch((err) => {
  console.error("[gateway] failed to start:", err);
  engine.kill();
  process.exit(1);
});
