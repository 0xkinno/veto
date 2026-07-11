import type { PolicyId } from "./types";

export const config = {
  port: Number(process.env.PORT ?? 8787),
  chainId: 196, // X Layer mainnet (payment settlement chain)
  rpcUrl: process.env.XLAYER_RPC_URL ?? "https://rpc.xlayer.tech",
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
    // Stablecoin used for pricing/settlement. USDG default (EIP-3009 native).
    asset: process.env.X402_ASSET ?? "0x4ae46a509f6b1d9056937ba4500cb143933d2dc8",
    assetName: process.env.X402_ASSET_NAME ?? "USDG",
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
