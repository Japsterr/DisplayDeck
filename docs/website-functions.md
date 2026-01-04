# DisplayDeck Website — Functions & Feature Overview

This document describes what the DisplayDeck website provides, how customers use it, and which problems it solves. It’s written for sales demos, onboarding, and product positioning.

---

## What DisplayDeck is

DisplayDeck is a digital signage platform that lets a business:

- upload and organize media (images/videos)
- build playlists (“campaigns”) and dynamic menus
- assign content to screens (“displays”)
- monitor what’s playing and review proof-of-play analytics

The website is the control panel: customers use it to configure content, devices, and users.

---

## Who uses the website

- **Owners / Admins**: manage subscription, users/roles, devices, audit history
- **Content Managers**: upload media, build campaigns, build menus, assign to displays
- **Viewers**: view status and analytics (read-only)

---

## Main areas of the website

### 1) Landing + pricing (public)

Purpose: explain the product, show examples, and convert visitors to sign-ups.

Typical content:

- product hero and benefits
- example menu/campaign visuals
- pricing tiers and plan comparisons

### 2) Authentication (public)

- sign up a new organization
- log in

### 3) Dashboard home

Purpose: give a fast overview of the organization.

Typical widgets:

- number of displays
- active campaigns
- media library stats
- quick links to create/assign content

### 4) Media library

Purpose: upload and manage media for campaigns and menus.

Capabilities:

- upload images/videos
- view media metadata (type/orientation)
- delete or update media metadata
- preview media via signed URLs (secure; buckets don’t need to be public)

### 5) Campaigns (playlists)

Purpose: build a playlist of content that will play on one or more screens.

Capabilities:

- create/update campaigns
- add items to a campaign (media or a menu board)
- set item order and per-item duration
- assign campaigns to one or more displays

### 6) Menu builder (dynamic menu boards)

Purpose: create structured menus (menus → sections → items) that can be shown as a campaign item.

Capabilities:

- create a menu board (choose a template/theme)
- create sections and items
- optionally import menu items from CSV (faster onboarding)
- attach uploaded media to menu items
- preview a menu via a public token link

### 7) Displays (device management)

Purpose: register screens, name them, set orientation, and connect them to content.

Capabilities:

- view all displays and their current status
- assign campaigns and (if supported) primary content
- remove a display
- unpair a display token (security action)

### 8) Now Playing

Purpose: answer “what is currently showing on each screen?”

Capabilities:

- show the currently active campaign item
- preview current media/menu content
- use this view during support calls to confirm device configuration quickly

### 9) Analytics (proof of play)

Purpose: show what content played, where, and how often.

Capabilities:

- aggregate play counts
- top media / top campaigns
- per-display activity summaries

### 10) Audit / token lifecycle history (ops + support)

Purpose: make device pairing and token lifecycle transparent.

Capabilities:

- token-centric history: see the full lifecycle for a token (issued/claimed/unpaired/rejected)
- device-centric history: see a device’s history across tokens by HardwareId (survives unpair)
- assignment snapshot counts captured on key lifecycle events (helps explain impact)

---

## Key customer flows

### Flow A — Add a new screen

1. Device shows a pairing QR / token
2. User claims the token in the dashboard to create a display
3. User assigns campaigns/menus to the display
4. Device heartbeats and starts playback

### Flow B — Build a campaign

1. Upload media to the library
2. Create a campaign and add items
3. Set durations and ordering
4. Assign campaign to one or more displays

### Flow C — Build a menu board

1. Create menu and choose a template
2. Add sections and items (or CSV import)
3. Attach images/prices/descriptions
4. Preview via public menu token
5. Add the menu as a campaign item for playback

### Flow D — Support / troubleshooting

1. Check Now Playing to confirm what the display should be showing
2. Check provisioning device history for pairing/unpairing events
3. Check analytics to confirm proof-of-play

---

## Security + reliability (what matters in the field)

- **JWT auth** for dashboard APIs
- **signed URLs** for private media downloads
- **same-origin proxy** for public menu media to reduce WebView/CORS/DNS issues on older devices
- **token unpair** endpoint to immediately sever device access
- **device history** retained by HardwareId even if tokens are rotated/unpaired

---

## How to demo the product (quick script)

1) Show landing/pricing and explain the value proposition

2) In dashboard:

- open Media Library and upload an image
- create a Campaign and add the image
- open Menus, create a menu, and preview the public menu link
- assign the campaign to a display
- open Now Playing to confirm what should be showing
- open Analytics to show proof-of-play

3) Optional: show device/token audit history to explain pairing security
