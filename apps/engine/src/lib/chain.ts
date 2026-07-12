import {
  createPublicClient,
  http,
  parseAbi,
  parseAbiItem,
  maxUint256,
  type PublicClient,
  type Address,
} from "viem";
import { config } from "./config";

/** Shared X Layer reader. One client, reused by every instrument. */
let client: PublicClient | null = null;
export function chain(): PublicClient {
  if (!client) client = createPublicClient({ transport: http(config.rpcUrl) });
  return client;
}

export const ERC20_ABI = parseAbi([
  "function approve(address spender, uint256 value) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
]);

export const APPROVAL_EVENT = parseAbiItem(
  "event Approval(address indexed owner, address indexed spender, uint256 value)"
);

export const UNLIMITED_THRESHOLD = maxUint256 / 2n;

/** Is this address a contract (has bytecode) or an EOA? */
export async function isContract(address: string): Promise<boolean> {
  const code = await chain().getBytecode({ address: address as Address });
  return Boolean(code && code !== "0x");
}

/** Bytecode size in bytes — a rough proxy for contract complexity. */
export async function codeSize(address: string): Promise<number> {
  const code = await chain().getBytecode({ address: address as Address });
  if (!code || code === "0x") return 0;
  return (code.length - 2) / 2;
}

/** Native balance in wei. */
export async function nativeBalance(address: string): Promise<bigint> {
  return chain().getBalance({ address: address as Address });
}

/** Outgoing transaction count — a proxy for account age/activity. */
export async function txCount(address: string): Promise<number> {
  return chain().getTransactionCount({ address: address as Address });
}

/** Current on-chain allowance for owner -> spender on a token. */
export async function allowanceOf(
  token: string,
  owner: string,
  spender: string
): Promise<bigint> {
  return chain().readContract({
    address: token as Address,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [owner as Address, spender as Address],
  }) as Promise<bigint>;
}

export interface TokenMeta {
  symbol: string;
  decimals: number;
}

/** Best-effort token metadata; falls back gracefully on non-standard tokens. */
export async function tokenMeta(token: string): Promise<TokenMeta> {
  try {
    const [symbol, decimals] = await Promise.all([
      chain().readContract({ address: token as Address, abi: ERC20_ABI, functionName: "symbol" }) as Promise<string>,
      chain().readContract({ address: token as Address, abi: ERC20_ABI, functionName: "decimals" }) as Promise<number>,
    ]);
    return { symbol, decimals: Number(decimals) };
  } catch {
    return { symbol: "UNKNOWN", decimals: 18 };
  }
}

export interface ApprovalLog {
  token: string;
  owner: string;
  spender: string;
  value: bigint;
  blockNumber: bigint;
  txHash: string;
}

/**
 * Every Approval event this wallet has ever emitted, within `lookback` blocks.
 * Chunked so public RPCs don't reject the range.
 */
export async function approvalHistory(
  owner: string,
  lookback = Number(process.env.APPROVAL_LOOKBACK_BLOCKS ?? 100_000)
): Promise<ApprovalLog[]> {
  const c = chain();
  const latest = await c.getBlockNumber();
  const span = BigInt(lookback);
  const from = latest > span ? latest - span : 0n;

  const CHUNK = 20_000n;

  // Build every range up front, then fetch them in PARALLEL. Sequential
  // scanning of 20 chunks took ~29s; this collapses it to a few seconds.
  const ranges: Array<[bigint, bigint]> = [];
  for (let start = from; start <= latest; start += CHUNK) {
    const end = start + CHUNK - 1n > latest ? latest : start + CHUNK - 1n;
    ranges.push([start, end]);
  }

  const settled = await Promise.allSettled(
    ranges.map(([start, end]) =>
      c.getLogs({
        fromBlock: start,
        toBlock: end,
        event: APPROVAL_EVENT,
        args: { owner: owner as Address },
      })
    )
  );

  const out: ApprovalLog[] = [];
  for (const r of settled) {
    if (r.status !== "fulfilled") continue; // a rejected range must not fail the audit
    for (const log of r.value) {
      const a = log.args as { owner?: Address; spender?: Address; value?: bigint };
      if (!a.owner || !a.spender || a.value === undefined) continue;
      out.push({
        token: log.address.toLowerCase(),
        owner: a.owner.toLowerCase(),
        spender: a.spender.toLowerCase(),
        value: a.value,
        blockNumber: log.blockNumber ?? 0n,
        txHash: log.transactionHash ?? "",
      });
    }
  }
  return out;
}
