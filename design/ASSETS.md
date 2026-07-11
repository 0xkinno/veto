# VETO — Visual Assets

Generated image assets live in `apps/web/public`. This file records the exact generation prompts so any asset can be re-created in the same visual grade.

## Palette (must match across every asset)

| Token        | Hex       | Use                          |
| ------------ | --------- | ---------------------------- |
| ivory        | `#F4F1E9` | page background              |
| ink          | `#141311` | primary text                 |
| emerald      | `#2E7A57` | ALLOW verdicts only          |
| amber        | `#9A6E1E` | WARN verdicts only           |
| crimson      | `#96302E` | VETO verdicts only           |
| slate        | `#4E5F78` | data / accent                |

---

## 1. Hero figure — `public/hero-figure.png`

Editorial illustration, anime-inspired anatomy, standing figure seen from behind at a warm sunrise/sunset horizon over rolling hills. Deep charcoal silhouette, backlit, generous sky above. Muted warm palette (ivory, pale sky blue, soft amber). Museum-quality negative space, no text, no logos, no UI. Aspect ratio 3:2.

Placement: full-bleed hero background, `object-fit: cover`, `object-position: center bottom`, soft top mask so the nav floats clean.

## 2. Sky hands — `public/hands-sky.png`

Two hands reaching toward each other across a bright blue sky with soft clouds, leaving a gap in the centre. Fine-art photographic style, clean, reverent. Aspect ratio 16:9.

Placement: full-bleed background of the "hand-off between agents" section; the token box floats in the centre gap.

---

## Notes

- Both images are embedded in `design/landing.reference.html` as base64 for a standalone preview.
- In the Next.js build they are served from `/public` and referenced with `next/image`.
- If regenerating, keep the light grade — the whole site lives in one continuous warm ivory world.

---

## Asset status in this scaffold

- `apps/web/public/hero-figure.png` — present (approved hero).
- `apps/web/public/hands-sky.png` — NOT bundled. Regenerate from the prompt above, or export it from the approved `design/landing.reference.html` hands section before the Phase 6 port.
