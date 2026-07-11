/** VETO design tokens — identical to the live site. */
export const C = {
  ivory: "#F4F1E9",
  stone: "#ECE8DD",
  card: "#FFFFFF",
  ink: "#141311",
  ink2: "#5D584C",
  ink3: "#948E7E",
  emerald: "#2E7A57",
  emeraldBg: "rgba(46,122,87,.10)",
  amber: "#9A6E1E",
  amberBg: "rgba(154,110,30,.10)",
  crimson: "#96302E",
  crimsonBg: "rgba(150,48,46,.09)",
  slate: "#4E5F78",
  line: "rgba(20,19,17,.08)",
};

export const F = {
  sans: "'Inter Tight', -apple-system, Segoe UI, sans-serif",
  serif: "'Newsreader', Georgia, serif",
  mono: "'IBM Plex Mono', ui-monospace, monospace",
};

/** Cinematic easing — slow out, slow in. */
export const EASE = (t: number) =>
  t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
