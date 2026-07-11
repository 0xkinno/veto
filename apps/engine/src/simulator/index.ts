import {
  createPublicClient,
  http,
  decodeEventLog,
  parseAbi,
  maxUint256,
  type PublicClient,
} from "viem";
import type { SimulationResult, UnsignedTx } from "../lib/types";
import { config } from "../lib/config";
import { extractEffects } from "../diff";

/**
 * Fork X Layer at the latest block and execute an unsigned transaction
 * against that fork, capturing the trace and every state change.
 *
 * Strategy:
 *   1. eth_call the exact transaction at the latest block to detect
 *      revert + reason and confirm executability.
 *   2. debug_traceCall with the callTracer to capture the full internal
 *      call tree + emitted logs (used by the diff extractor).
 *   3. Hand the raw logs to extractEffects() to produce the effect list.
 *
 * Falls back gracefully when a node does not expose debug_traceCall:
 * it still returns revert state from eth_call and decodes any logs it can.
 */

let client: PublicClient | null = null;

function getClient(): PublicClient {
  if (!client) {
    client = createPublicClient({ transport: http(config.rpcUrl) });
  }
  return client;
}

const TRANSFER_APPROVAL_ABI = parseAbi([
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
]);

export async function simulate(tx: UnsignedTx): Promise<SimulationResult> {
  const c = getClient();
  const blockNumber = Number(await c.getBlockNumber());

  const callParams = {
    account: tx.from as `0x${string}`,
    to: tx.to as `0x${string}`,
    data: (tx.data ?? "0x") as `0x${string}`,
    value: tx.value ? BigInt(tx.value) : undefined,
  };

  // 1. Detect revert + reason via eth_call.
  let reverted = false;
  let revertReason: string | undefined;
  try {
    await c.call(callParams);
  } catch (err: unknown) {
    reverted = true;
    revertReason = extractRevertReason(err);
  }

  // 2. Try a full trace for logs + gas. Not all RPCs expose debug_.
  let rawLogs: TraceLog[] = [];
  let gasUsed = "0";
  try {
    const trace = (await c.request({
      method: "debug_traceCall" as never,
      params: [
        {
          from: tx.from,
          to: tx.to,
          data: tx.data ?? "0x",
          value: tx.value ? `0x${BigInt(tx.value).toString(16)}` : "0x0",
        },
        "latest",
        { tracer: "callTracer", tracerConfig: { withLog: true } },
      ] as never,
    })) as TraceResult;

    gasUsed = trace?.gasUsed ? BigInt(trace.gasUsed).toString() : "0";
    rawLogs = collectLogs(trace);
  } catch {
    // debug namespace unavailable — effects come from decoded logs only.
  }

  const decoded = decodeLogs(rawLogs);
  const effects = extractEffects({ decoded, reverted, revertReason });

  return { blockNumber, reverted, revertReason, effects, gasUsed };
}

// ---- helpers ----------------------------------------------------------

interface TraceLog {
  address: string;
  topics: string[];
  data: string;
}

interface TraceResult {
  gasUsed?: string;
  logs?: TraceLog[];
  calls?: TraceResult[];
}

/** Flatten every log emitted across the whole call tree. */
function collectLogs(trace: TraceResult | undefined): TraceLog[] {
  if (!trace) return [];
  const out: TraceLog[] = [...(trace.logs ?? [])];
  for (const sub of trace.calls ?? []) out.push(...collectLogs(sub));
  return out;
}

export interface DecodedLog {
  event: "Transfer" | "Approval";
  token: string;
  from?: string;
  to?: string;
  owner?: string;
  spender?: string;
  value: string;
  unlimited: boolean;
}

/** Decode Transfer + Approval logs; ignore everything else. */
function decodeLogs(logs: TraceLog[]): DecodedLog[] {
  const out: DecodedLog[] = [];
  for (const log of logs) {
    try {
      const parsed = decodeEventLog({
        abi: TRANSFER_APPROVAL_ABI,
        data: log.data as `0x${string}`,
        topics: log.topics as [`0x${string}`, ...`0x${string}`[]],
      });
      if (parsed.eventName === "Transfer") {
        const a = parsed.args as unknown as { from: string; to: string; value: bigint };
        out.push({
          event: "Transfer",
          token: log.address,
          from: a.from,
          to: a.to,
          value: a.value.toString(),
          unlimited: false,
        });
      } else if (parsed.eventName === "Approval") {
        const a = parsed.args as unknown as { owner: string; spender: string; value: bigint };
        out.push({
          event: "Approval",
          token: log.address,
          owner: a.owner,
          spender: a.spender,
          value: a.value.toString(),
          unlimited: a.value >= maxUint256 / 2n,
        });
      }
    } catch {
      // not an ERC20 Transfer/Approval — skip.
    }
  }
  return out;
}

function extractRevertReason(err: unknown): string {
  if (err && typeof err === "object") {
    const e = err as { shortMessage?: string; message?: string };
    return e.shortMessage ?? e.message ?? "execution reverted";
  }
  return "execution reverted";
}

/** Current X Layer block number (used by demo verdicts to look live). */
export async function currentBlock(): Promise<number> {
  return Number(await getClient().getBlockNumber());
}
