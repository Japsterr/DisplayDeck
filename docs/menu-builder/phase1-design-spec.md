# Phase 1 Design Spec — Templates + Tokens + CRUD + Rendering

This spec is designed to keep DisplayDeck’s existing website theme and UI standards (Tailwind + shadcn patterns), while adding a new feature area for digital menu boards.

## Scope

Phase 1 includes:
- Templates + theme tokens (ThemeConfig)
- Menu/Section/Item CRUD
- A display rendering route (player) that renders menus from JSON
- Campaign integration (optional in Phase 1): allow a campaign playlist item to reference a menu

## Entities

### Menu
- `MenuId` (int)
- `OrganizationId` (int)
- `Name` (string)
- `TemplateId` (string) — e.g. `board-3col`, `board-hero-right`
- `ThemeConfig` (json)
- `CreatedAt`, `UpdatedAt`

### MenuSection
- `SectionId` (int)
- `MenuId` (int)
- `Name` (string)
- `DisplayOrder` (int)
- `Slot` (string, nullable) — for templates that use fixed slots (`left`, `center`, `right`, `hero`, etc.)

### MenuItem
- `MenuItemId` (int)
- `SectionId` (int)
- `Name` (string)
- `Description` (string, nullable)
- `Price` (decimal, nullable)
- `IsAvailable` (bool, default true)
- `DisplayOrder` (int)
- optional `ImageUrl` (string)
- optional `Badge` (string)

## ThemeConfig (tokens)

Stored as JSON. Templates should consume tokens only (no hardcoded colors).

Recommended shape:
- `palette`: { `bg`, `panelBg`, `text`, `mutedText`, `accent`, `danger` }
- `typography`: { `fontFamily`, `titleSize`, `sectionSize`, `itemSize`, `priceSize`, `weightTitle`, `weightItem` }
- `layout`: { `gap`, `padding`, `columnGap`, `rowGap`, `showPrices`, `currencySymbol` }
- `background`: { `imageUrl`, `overlay`: { `enabled`, `color`, `opacity` } }
- `availability`: { `mode`: `hide|dim|badge`, `soldOutLabel`: "SOLD OUT" }

## Templates (Phase 1)

Deliver 2 templates:

1) `board-3col`
- 3 columns
- each column contains one or more sections

2) `board-hero-right`
- left: menu sections
- right: hero promo area (background image + headline)

Templates should support 16:9 and scale cleanly.

## Website UX

Add a new dashboard area:
- `/dashboard/menus` — list menus
- `/dashboard/menus/new` — create
- `/dashboard/menus/[id]` — editor

Editor layout:
- Left: sections and items (reorder with drag/drop optional in Phase 1)
- Center: live preview (select aspect ratio 16:9, 9:16)
- Right: properties (Theme / Section / Item)

Keep styling consistent with existing Dashboard UI (Card, Button, Inputs, Dialog, Tabs).

## Player rendering

Add a public render route:
- `/display/menu/[menuId]` (website route)

Behavior:
- fetch menu JSON from API
- render with selected template + tokens
- auto-refresh (poll UpdatedAt every 30–60s)

## API contract (Phase 1)

Minimal endpoints (all org-scoped):
- `GET /organizations/{orgId}/menus`
- `POST /organizations/{orgId}/menus`
- `GET /menus/{menuId}` (includes sections + items)
- `PATCH /menus/{menuId}` (name/template/theme)
- `POST /menus/{menuId}/sections`
- `PATCH /menu-sections/{sectionId}`
- `DELETE /menu-sections/{sectionId}`
- `POST /menu-sections/{sectionId}/items`
- `PATCH /menu-items/{menuItemId}`
- `DELETE /menu-items/{menuItemId}`

## Success criteria
- A client can create a menu, edit items/prices/availability, and see the display update without re-uploading an image.
- Defaults produce readable boards (contrast-safe).
- UI follows DisplayDeck website theme.
