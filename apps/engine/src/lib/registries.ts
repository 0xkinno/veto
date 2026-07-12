/**
 * Address registries: known drainers and registered recipients.
 *
 * The drainer set is seeded with well-documented malicious addresses and can
 * be extended at boot from a live threat feed (Scam Sniffer, Chainabuse) via
 * DRAINER_FEED_URL, or from a local list via DRAINER_ADDRESSES.
 *
 * An empty set would make every drainer check silently pass. It does not
 * start empty.
 */

/**
 * Seed set — publicly documented malicious / burn-adjacent addresses.
 * These are the canonical null and dead addresses plus known drainer
 * infrastructure. Extend via the env feed for production coverage.
 */
const SEED_DRAINERS: string[] = [
  // canonical burn / null — funds sent here are unrecoverable
  "0x0000000000000000000000000000000000000000",
  "0x000000000000000000000000000000000000dead",
  "0xdead000000000000000042069420694206942069",
  // Inferno Drainer infrastructure (widely documented)
  "0x0000db5c8b030ae20308ac975898e09741e70000",
  // Angel Drainer infrastructure (widely documented)
  "0x412f10aad96fd78da6736387e2c84931ac20313f",
  // Monkey Drainer infrastructure (widely documented)
  "0x0d0e364aa7852291883c162b22d6d81f6355428f",
];

const drainers = new Set<string>(SEED_DRAINERS.map((a) => a.toLowerCase()));

/** Registered recipients — the caller's own allowlist for treasury-strict. */
const registered = new Set<string>();

export function isKnownDrainer(address: string): boolean {
  return drainers.has(address.toLowerCase());
}

export function isRegistered(address: string): boolean {
  return registered.has(address.toLowerCase());
}

export function loadDrainers(addresses: string[]): void {
  for (const a of addresses) {
    if (/^0x[a-fA-F0-9]{40}$/.test(a)) drainers.add(a.toLowerCase());
  }
}

export function loadRegistered(addresses: string[]): void {
  for (const a of addresses) {
    if (/^0x[a-fA-F0-9]{40}$/.test(a)) registered.add(a.toLowerCase());
  }
}

export function drainerCount(): number {
  return drainers.size;
}

/**
 * Boot-time hydration.
 *   DRAINER_ADDRESSES  comma-separated list
 *   DRAINER_FEED_URL   a JSON endpoint returning string[] or {address}[]
 * Both are optional; the seed set stands on its own.
 */
export async function hydrateRegistries(): Promise<void> {
  const inline = process.env.DRAINER_ADDRESSES;
  if (inline) loadDrainers(inline.split(",").map((s) => s.trim()));

  const registeredInline = process.env.REGISTERED_RECIPIENTS;
  if (registeredInline)
    loadRegistered(registeredInline.split(",").map((s) => s.trim()));

  const feed = process.env.DRAINER_FEED_URL;
  if (!feed) return;

  try {
    const res = await fetch(feed);
    if (!res.ok) return;
    const data = (await res.json()) as unknown;
    const list = Array.isArray(data)
      ? data.map((d) =>
          typeof d === "string" ? d : (d as { address?: string }).address ?? ""
        )
      : [];
    loadDrainers(list.filter(Boolean));
  } catch {
    // A feed outage must never stop the engine. The seed set still applies.
  }
}
