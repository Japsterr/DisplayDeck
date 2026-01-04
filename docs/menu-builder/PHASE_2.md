# Menu Builder — Phase 2 (Enhanced QSR Templates)

Date: 2026-01-04

Phase 2 goal: Enable creation of professional-quality **Quick Service Restaurant (QSR)** style menu boards like those seen in fast-food chains, drive-thrus, and modern food establishments.

## New Templates

### QSR Board (`qsr`)
- Professional fast-food style layout
- Large product images with prominent price badges
- Section cards with color-coded headers
- Optimized for indoor displays
- Grid-based item layout (2-3 columns)

### Drive-Thru (`drivethru`)
- Maximum legibility for outdoor viewing
- Numbered items for easy ordering
- Bold section headers with high contrast
- Simplified layout with larger fonts
- Optimized for sunlight conditions

## Enhanced ThemeConfig Options

New theme configuration keys available:

### Colors
- `priceBadgeColor` — Background color for price badges (defaults to `accentColor`)
- `sectionHeaderColor` — Background color for section headers

### Layout
- `layoutColumns` — Force 1, 2, or 3 columns (or "auto")
- `itemCardStyle` — `standard`, `compact`, `image-left`, `image-right`, `hero`

## New QSR Color Palettes

Added 6 new fast-food themed palettes:

| Palette | Description | Best For |
|---------|-------------|----------|
| Burger Red | Classic red & yellow | Burger joints, drive-thrus |
| Golden Arches | Bold yellow on dark | QSR, high visibility |
| Fried Crispy | Warm orange tones | Chicken shops, fried food |
| Pizza Parlor | Italian red & cream | Pizzerias |
| Fresh Salad | Healthy greens | Salad bars, health food |
| Coffee Roast | Rich brown tones | Coffee shops, cafes |

## Database Enhancements

New migration: `2026-01-04_enhance_menu_items.sql`

### MenuItems — New Columns
- `Badges` (JSONB) — Array of badge objects for labels like NEW, HOT, SPICY
- `Calories` (INT) — Calorie count for nutrition info
- `Variants` (JSONB) — Size/option variants with different prices
- `ComboItems` (JSONB) — List of items included in combos
- `IsPromo` (BOOLEAN) — Highlight as promotional item
- `PromoLabel` (VARCHAR) — e.g., "Limited Time", "Special Offer"
- `OriginalPriceCents` (INT) — For showing strikethrough "was" price

### MenuSections — New Columns
- `PanelIndex` (INT) — For multi-screen displays
- `BackgroundColor` (VARCHAR) — Per-section background override
- `TitleColor` (VARCHAR) — Per-section title color
- `LayoutStyle` (VARCHAR) — `grid`, `list`, `hero`, `combo`

### New Tables

#### MenuPromos
Promotional banners and featured deals:
- `Title`, `Subtitle` — Display text
- `ImageUrl` — Hero image
- `BackgroundColor`, `TextColor` — Styling
- `PriceCents`, `PromoLabel` — Deal pricing
- `ValidUntil` — Expiration countdown
- `LayoutPosition` — `top`, `bottom`, `left`, `right`, `overlay`
- `PanelIndex` — Multi-screen assignment

#### MenuCombos
Combo/meal sets grouping multiple items:
- `Name`, `Description`, `ImageUrl` — Display info
- `PriceCents`, `OriginalPriceCents` — Combo pricing with savings
- `Badges` — Like individual items
- `IncludedItems` (JSONB) — What's in the combo

## Badge System

Badges can be added to items to highlight special attributes:

| Badge Type | Default Label | Color |
|------------|---------------|-------|
| `new` | NEW | Green |
| `hot` | HOT | Red |
| `spicy` | 🌶️ | Orange |
| `bestseller` | ★ BEST | Yellow |
| `popular` | POPULAR | Purple |
| `vegan` | 🌱 VEGAN | Green |
| `vegetarian` | VEG | Lime |
| `glutenfree` | GF | Cyan |
| `halal` | HALAL | Emerald |
| `limited` | LIMITED | Pink |
| `promo` | DEAL | Accent |

Example badge JSON:
```json
[
  {"type": "new"},
  {"type": "spicy", "level": 2},
  {"type": "bestseller", "label": "TOP SELLER"}
]
```

## Variant Pricing

Support for size-based pricing:
```json
[
  {"name": "Small", "priceCents": 2999},
  {"name": "Medium", "priceCents": 3999},
  {"name": "Large", "priceCents": 4999}
]
```

## Combo Items

List of included items in a combo:
```json
[
  {"name": "Burger", "imageUrl": "mediafile:123"},
  {"name": "Fries"},
  {"name": "Drink", "size": "Medium"}
]
```

## Multi-Panel Support

For multi-screen displays (e.g., 3-panel drive-thru):
- `MenuSections.PanelIndex` — Assign sections to screens (0, 1, 2)
- `MenuPromos.PanelIndex` — Assign promos to screens
- Player app filters by panel index

## Best Practices for QSR Menus

### Images
- Use high-quality product photos (min 500x500px)
- Consistent styling across all items
- Square aspect ratio works best
- Optimize for fast loading

### Layout
- Group related items in sections
- Use 2-3 columns for landscape displays
- Feature combos prominently
- Keep descriptions short (1-2 lines max)

### Colors
- High contrast for readability
- Use accent color for prices
- Section headers should stand out
- Consistent branding

### Pricing
- Show prices prominently
- Use promo pricing for deals
- Highlight savings on combos
- Consider showing original prices for discounts

## Template Selection Guide

| Template | Best For | Key Features |
|----------|----------|--------------|
| Classic | Restaurants, cafes | Clean sections, flexible layout |
| Minimal | Modern venues, bars | Simple, elegant design |
| Neon | Entertainment, nightlife | Glowing effects, bold colors |
| QSR | Fast food, takeaway | Large images, price badges |
| Drive-Thru | Outdoor displays | Numbered items, max legibility |

## Future Roadmap (Phase 3+)

- [ ] Drag-and-drop section/item reordering
- [ ] POS system integration
- [ ] Scheduled price changes
- [ ] A/B testing for menu layouts
- [ ] Analytics (popular items, view counts)
- [ ] Multi-language support
- [ ] Animated transitions
- [ ] Video backgrounds
- [ ] QR code integration
