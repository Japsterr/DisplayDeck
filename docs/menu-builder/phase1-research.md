# Phase 1 Research — Dynamic Menu Builder

Goal: identify proven UX + rendering patterns for **digital menu boards** (like your examples), and translate them into a Phase 1 implementation that fits DisplayDeck:
- Website dashboard: Next.js 16 + Tailwind + shadcn
- Backend: Delphi WebBroker API
- Playback: displays should render menus **from structured data**, not static images

## Key findings (actionable)

### 1) Treat menu boards as templates + tokens (not freeform first)
- The template ecosystems (e.g., Canva’s large library of menu-board templates) shows that most businesses want to start from a **known-good layout** and then customize colors/fonts/images.
- Implication for DisplayDeck Phase 1: ship a small set of high-quality templates (2–4) and a token-based theme editor.

Reference:
- Canva menu board template library: https://www.canva.com/templates/search/menu-board/

### 2) Contrast must be guaranteed (especially over background images)
- WCAG guidance: minimum contrast ratio 4.5:1 for normal text, 3:1 for “large text”.
- Implication: in our templates, we should support “panel overlays” (e.g., semi-opaque dark/light rectangles) behind text and optional background blur/shade to preserve readability.

Reference:
- WCAG 2.1 SC 1.4.3 Contrast (Minimum): https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html

### 3) Use typography scales (tokens), not ad-hoc sizes
- Material 3 typography emphasizes consistent type roles (display/headline/title/body/label) and token-based scaling.
- Implication: in ThemeConfig we store a type scale (base sizes + weights), and templates reference roles (e.g., section title uses `titleLarge`, item name uses `bodyLarge`, price uses `titleMedium`).

Reference:
- Material 3 typography overview: https://m3.material.io/styles/typography/overview

### 4) Consistency and predictability are the product (not infinite flexibility)
- Microsoft design guidance emphasizes predictable patterns and consistent UI behavior.
- Implication: for a client-facing Menu Builder, “structured editing” (sections/items + a few layout choices) is more successful than a power-user-only canvas editor as the default.

Reference:
- Windows app design overview: https://learn.microsoft.com/en-us/windows/apps/design/

### 5) Product trends we should match in Phase 1
- **Template-first** editors with live preview.
- Strong defaults for 16:9 (landscape menu boards), with safe margins.
- Real-time updates via lightweight data (JSON) instead of large images.
- “Sold out” handling as a first-class state (hide vs grey out vs badge).

## Translate to Phase 1 decisions

- Start with **templates** rather than a freeform canvas.
- ThemeConfig is a JSON token set (colors/fonts/panels) designed to keep contrast safe.
- Player renders menu using HTML/CSS from JSON (fast updates, tiny payload).
- Later phases add duplication, CSV import, and POS-driven updates.
