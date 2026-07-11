/**
 * Address registries: known drainers and registered recipients.
 *
 * Seeded here for deterministic rule behaviour; in production these load
 * from a refreshed threat feed (drainers) and the caller's own ledger
 * (registered recipients) at boot. The lookups below are the stable
 * interface the rules depend on — swap the backing store freely.
 */

// Seed drainer set. Extend from a live feed (e.g. Scam Sniffer / Chainabuse)
// via loadDrainers() at engine start.
const drainers = new Set<string>(
  ([] as string[])
    // placeholder entries; replace with a real feed on boot.
    .map((a) => a.toLowerCase())
);

// Registered recipients for treasury-strict callers. Populated per-caller
// in Phase 4 from the submitted ledger; empty here means "nothing trusted".
const registered = new Set<string>();

export function isKnownDrainer(address: string): boolean {
  return drainers.has(address.toLowerCase());
}

export function isRegistered(address: string): boolean {
  return registered.has(address.toLowerCase());
}

export function loadDrainers(addresses: string[]): void {
  for (const a of addresses) drainers.add(a.toLowerCase());
}

export function loadRegistered(addresses: string[]): void {
  for (const a of addresses) registered.add(a.toLowerCase());
}
