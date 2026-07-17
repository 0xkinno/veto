// VETO A2MCP server.
//
// Exposes the five instruments as MCP tools over Streamable HTTP so
// OKX.AI's marketplace bot (an MCP client) can discover and call them.
// Each tool forwards to the internal engine's demo route and returns the
// JSON result as MCP tool content. The engine's verdict logic is untouched.
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import type { Request, Response } from "express";

const ENGINE_BASE = process.env.ENGINE_INTERNAL_URL ?? "http://127.0.0.1:8788";

async function callEngine(path: string, body: unknown) {
  const res = await fetch(`${ENGINE_BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body ?? {}),
  });
  const data = await res.json();
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
  };
}

export function buildVetoMcpServer(): McpServer {
  const server = new McpServer({ name: "veto", version: "1.0.0" });

  server.registerTool(
    "veto_verdict",
    {
      title: "Pre-signature verdict",
      description:
        "Submit an unsigned transaction and its stated intent. VETO simulates it on X Layer, diffs intent against real effect, and returns ALLOW, WARN or VETO with a hash-committed evidence bundle.",
      inputSchema: {
        tx: z.object({}).passthrough().describe("The unsigned transaction object (from, to, data, value, chainId)"),
        intent: z.string().describe("What the agent believes the transaction does"),
        policy: z
          .enum(["treasury-strict", "standard", "degen-loose"])
          .optional()
          .describe("Risk posture; defaults to standard"),
      },
    },
    async ({ tx, intent, policy }) =>
      callEngine("/demo/verdict", { tx, intent: { summary: intent }, policy })
  );

  server.registerTool(
    "veto_approvals",
    {
      title: "Approval hygiene",
      description:
        "Audit every live token allowance a wallet has granted and return the dangerous ones with revocation guidance.",
      inputSchema: { wallet: z.string().describe("The wallet address to audit") },
    },
    async ({ wallet }) => callEngine("/demo/approvals", { wallet })
  );

  server.registerTool(
    "veto_payload",
    {
      title: "Task-payload screening",
      description:
        "Screen an inbound task payload for prompt injection, credential extraction, embedded approval calldata, and drainer patterns before an agent accepts it.",
      inputSchema: { payload: z.any().describe("The inbound task payload to screen") },
    },
    async ({ payload }) => callEngine("/demo/payload", { payload })
  );

  server.registerTool(
    "veto_counterparty",
    {
      title: "Counterparty check",
      description:
        "An evidence-graded trust ruling on any address or contract before an agent engages, read live from X Layer.",
      inputSchema: { address: z.string().describe("The address or contract to check") },
    },
    async ({ address }) => callEngine("/demo/counterparty", { address })
  );

  server.registerTool(
    "veto_forensics",
    {
      title: "Post-incident forensics",
      description:
        "Replay any historical X Layer transaction through the rule pipeline and report what VETO would have ruled, with a post-mortem.",
      inputSchema: {
        txHash: z.string().describe("The historical transaction hash to replay"),
        policy: z.enum(["treasury-strict", "standard", "degen-loose"]).optional(),
        intent: z.string().optional(),
      },
    },
    async ({ txHash, policy, intent }) =>
      callEngine("/demo/forensics", { txHash, policy, intent })
  );

  return server;
}

// Stateless MCP over Streamable HTTP: a fresh server+transport per request.
// This is the simplest, most compatible mode for a marketplace bot that
// connects, lists, calls, and disconnects.
export async function handleMcpRequest(req: Request, res: Response) {
  const server = buildVetoMcpServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  });
  res.on("close", () => {
    transport.close();
    server.close();
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, (req as unknown as { body: unknown }).body);
}
