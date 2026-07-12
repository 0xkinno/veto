import { config } from "../lib/config";
import type { PaymentRequirements } from "./facilitator";

/** Convert a human price ("0.15") to atomic units for the configured asset. */
export function toAtomic(human: string): string {
  const decimals = config.x402.assetDecimals;
  const [whole, frac = ""] = human.split(".");
  const fracPadded = (frac + "0".repeat(decimals)).slice(0, decimals);
  const atomic = BigInt(whole) * 10n ** BigInt(decimals) + BigInt(fracPadded || "0");
  return atomic.toString();
}

/** Build the PaymentRequirements for a priced endpoint. */
export function requirementsFor(
  endpoint: keyof typeof config.pricing,
  resourceUrl: string
): PaymentRequirements {
  const amount = toAtomic(config.pricing[endpoint]);
  return {
    scheme: config.x402.scheme,
    network: config.x402.network,
    amount,
    asset: config.x402.asset,
    payTo: config.x402.payTo,
    maxTimeoutSeconds: config.x402.maxTimeoutSeconds,
    // Include decimals so a consumer never has to resolve the token itself.
    extra: {
      name: config.x402.assetName,
      version: config.x402.assetVersion,
      decimals: config.x402.assetDecimals,
    },
  };
}

/** The full 402 body an agent needs to construct its payment. */
export function challengeFor(
  endpoint: keyof typeof config.pricing,
  resourceUrl: string
) {
  return {
    x402Version: config.x402.x402Version,
    accepts: [requirementsFor(endpoint, resourceUrl)],
    resource: { url: resourceUrl },
    error: "payment required",
  };
}
