import type { PolicyId } from "./types";

export const config = {
  port: Number(process.env.INTERNAL_PORT ?? 8788),

  // ---- SIMULATION CHAIN -------------------------------------------------
  // The chain whose transactions VETO verifies. This MUST match the chain
  // the calling agent actually operates on. OKX.AI agents transact on
  // X Layer mainnet (196), so this defaults to mainnet.
  chainId: Number(process.env.XLAYER_CHAIN_ID ?? 196),
  rpcUrl: process.env.XLAYER_RPC_URL ?? "https://rpc.xlayer.tech",

  // ---- ATTESTATION CHAIN ------------------------------------------------
  // Where the VetoAttestation contract lives. May differ from the simulation
  // chain (e.g. contract on testnet while verifying mainnet transactions).
  // Falls back to the simulation RPC when not set.
  attestationRpcUrl:
    process.env.ATTESTATION_RPC_URL ??
    process.env.XLAYER_RPC_URL ??
    "https://rpc.xlayer.tech",
  attestationAddress: process.env.ATTESTATION_ADDRESS ?? "",
  attesterKey: process.env.ATTESTER_PRIVATE_KEY ?? "",

  redisUrl: process.env.REDIS_URL ?? "",

  // ---- x402 pay-per-call (OKX Facilitator, exact + EIP-3009) -----------
  x402: {
    // OKX Facilitator base URL + endpoint paths.
    baseUrl: process.env.OKX_API_BASE ?? "https://web3.okx.com",
    verifyPath: "/api/v6/pay/x402/verify",
    settlePath: "/api/v6/pay/x402/settle",
    settleStatusPath: "/api/v6/pay/x402/settle/status",
    supportedPath: "/api/v6/pay/x402/supported",
    // OKX API credentials (from the OKX dev portal). Payment enforces only
    // when all three are set; otherwise the gate degrades to open + logs.
    apiKey: process.env.OKX_API_KEY ?? "",
    apiSecret: process.env.OKX_API_SECRET ?? "",
    apiPassphrase: process.env.OKX_API_PASSPHRASE ?? "",
    // Where settled USDT lands — VETO's receiving wallet.
    payTo: process.env.VETO_PAYTO_ADDRESS ?? "",
    // Settlement network (CAIP-2) + protocol version.
    network: "eip155:196",
    x402Version: 2,
    scheme: "exact",
    // Stablecoin used for pricing/settlement.
    // USDT on X Layer mainnet — the asset OKX's task system resolves.
    asset: process.env.X402_ASSET ?? "0x1e4a5963abfd975d8c9021ce480b42188849d41d",
    assetName: process.env.X402_ASSET_NAME ?? "USDT",
    assetVersion: process.env.X402_ASSET_VERSION ?? "2",
    assetDecimals: Number(process.env.X402_ASSET_DECIMALS ?? 6),
    maxTimeoutSeconds: 60,
  },

  // Human-readable price per ruling (major units of the asset above).
  pricing: {
    verdict: "0.15",
    approvals: "0.30",
    payload: "0.20",
    counterparty: "0.10",
    forensics: "0.50",
  },
} as const;

export interface PolicyProfile {
  id: PolicyId;
  /** true = any approval to an unknown spender is a hard VETO */
  denyUnknownApprovals: boolean;
  /** slippage ceiling as a fraction, e.g. 0.03 = 3% */
  slippageCeiling: number;
  /** true = recipients must be on a registered ledger */
  registeredRecipientsOnly: boolean;
}

export const policies: Record<PolicyId, PolicyProfile> = {
  "treasury-strict": {
    id: "treasury-strict",
    denyUnknownApprovals: true,
    slippageCeiling: 0.01,
    registeredRecipientsOnly: true,
  },
  standard: {
    id: "standard",
    denyUnknownApprovals: false,
    slippageCeiling: 0.03,
    registeredRecipientsOnly: false,
  },
  "degen-loose": {
    id: "degen-loose",
    denyUnknownApprovals: false,
    slippageCeiling: 0.08,
    registeredRecipientsOnly: false,
  },
};
