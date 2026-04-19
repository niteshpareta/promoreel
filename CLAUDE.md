# StatusPro: Status Video Maker

**Owner:** Nitesh (BinaryScript) | **Target Launch:** Google Play India (Month 6) → iOS (v2)

## What This App Is

StatusPro is an **offline-first** Flutter app that lets small Indian shop owners create professional 30-second vertical videos for WhatsApp Status in under 90 seconds. No AI, no cloud, no templates, no third-party APIs. Everything runs on-device.

The primary user is "Rajesh" — a 38-year-old electronics/hardware/jewelry shop owner in a tier-2/3 Indian city (Kota, Jaipur, Indore). He runs his storefront via WhatsApp Business with 400 contacts and posts daily offers, new stock, or greetings. He is non-technical, often one-handed, and values speed over features.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) — Android first, iOS later |
| UI | Flutter widgets + custom painter for canvas preview |
| Video Processing | `ffmpeg_kit_flutter` (LGPL) |
| Animated Overlays | `lottie` Flutter package |
| Local DB | `drift` (SQLite) — branding presets, video history, settings |
| State Management | Riverpod |
| Billing (Android) | `in_app_purchase` (Google Play Billing) |
| Ads (free tier) | `google_mobile_ads` (AdMob) |
| Crash Reporting | Firebase Crashlytics via `firebase_crashlytics` |
| File Picking | `photo_manager` or `image_picker` |
| Share | `share_plus` + `android_intent_plus` for WhatsApp targeting |
| Fonts | Google Fonts (Noto Sans Devanagari + Latin) |

**Min SDK:** Android 24 (iOS 13+)  
**Package ID:** `com.binaryscript.statuspro`

## Project Structure

```
lib/
├── main.dart
├── app.dart                    # MaterialApp, theme, routing
├── core/
│   ├── theme/                  # StatusPro color tokens, text styles, theme data
│   ├── router/                 # GoRouter route definitions
│   ├── l10n/                   # Hindi + English ARB files
│   └── constants/              # output specs, limits, asset paths
├── features/
│   ├── home/                   # Home screen + "New Status Video" CTA
│   ├── picker/                 # Gallery multi-select (photos + videos)
│   ├── editor/                 # Canvas preview + motion style picker
│   ├── text_overlay/           # Headline + subtext input
│   ├── music/                  # Bundled music library picker
│   ├── branding/               # One-time branding setup + toggle
│   ├── export/                 # Render progress + share sheet
│   ├── paywall/                # Subscription tiers + free trial
│   └── onboarding/             # First-launch, Hindi-first
├── engine/
│   ├── motion_style_engine.dart # FFmpeg filter_complex generator from JSON spec
│   ├── text_renderer.dart       # Canvas → PNG (crisp Devanagari rendering)
│   ├── branding_compositor.dart # Bottom strip overlay
│   ├── audio_mixer.dart         # Music trim + fade
│   └── media_encoder.dart       # Final H.264 encode via ffmpeg_kit
├── data/
│   ├── db/                      # Drift database, DAOs, tables
│   ├── models/                  # MotionStyle, BrandingPreset, VideoProject
│   └── repositories/            # BrandingRepository, VideoHistoryRepository
└── billing/
    └── billing_manager.dart     # Subscription state, paywall gating
```

## Brand Identity & Theme

### Color Palette

| Token | Hex | Use |
|-------|-----|-----|
| `brandPrimary` | `#7C4DFF` | Electric Violet — CTAs, active states, progress |
| `brandPrimaryDark` | `#5E35B1` | Pressed/dark variant of primary |
| `brandSecondary` | `#FF6E40` | Coral Orange — accents, highlights, Pro badge |
| `brandSecondaryDark` | `#E64A19` | Pressed/dark variant of secondary |
| `bgDark` | `#0D0D1A` | Main background (dark theme) |
| `bgSurface` | `#1A1A2E` | Cards, bottom sheets, modal surfaces |
| `bgElevated` | `#252540` | Elevated cards, selected states |
| `textPrimary` | `#FFFFFF` | Primary text (dark theme) |
| `textSecondary` | `#B0AFCC` | Captions, hints, secondary labels |
| `proGold` | `#FFB300` | Pro/Business tier badges, paywall highlights |
| `successGreen` | `#00C853` | Export complete, success states |

### Design Principles

- **Dark-first** — premium video editor feel; the dark canvas makes user content pop
- **One-finger operation** — 48dp+ touch targets everywhere; no precision gestures
- **Max 3 taps** from home screen to starting an export
- **Live preview always visible** during editing — user sees the result before rendering
- **Hindi first** — all UI strings default to Hindi on first launch in India

## Core User Flow (Target: ≤90 seconds)

1. Launch → tap "New Status Video" (1s)
2. Gallery picker — multi-select up to 10 assets (10s)
3. Auto-arrange on vertical canvas, optional drag reorder (5s)
4. Type headline (60 chars) + optional subtext (100 chars), live preview (15s)
5. Swipe through 12 motion styles, preview updates live (15s)
6. Tap a music track or "no music" (10s)
7. Tap "Share to Status" → render (15–30s) → share sheet → WhatsApp (10s)

## Motion Style Engine (12 Styles — Core Technical Asset)

Each style = deterministic FFmpeg `filter_complex` + Lottie overlay spec. Given N assets and M seconds, produces a mathematically consistent premium video. No content templates — styles are motion math only.

| Family | Styles |
|--------|--------|
| **Subtle** (jewelry, boutique, wedding) | Slow Zoom, Ken Burns Pan, Soft Crossfade, Elegant Slide |
| **Energetic** (electronics, sales, offers) | Quick Cut Beat Sync, Bold Slide, Flash Reveal, Grid Pop |
| **Informational** (real estate, coaching, clinic) | Split Screen Info, Bottom-Third Highlight, Progressive Reveal, Caption Stack |

Engine reads a JSON spec → generates FFmpeg command at runtime.

## Output Specs

| Setting | Value |
|---------|-------|
| Resolution | 720×1280 (portrait) |
| Codec | H.264 |
| Bitrate | ~2 Mbps |
| Audio | AAC |
| Duration | 30 seconds |
| File size | <16 MB (WhatsApp limit) |
| Paid 1080p | 1080×1920 portrait |

## Export Performance Targets

| Device | Target |
|--------|--------|
| Low (Redmi A2, 2GB RAM) | <60s |
| Mid (Redmi Note 12, 6GB) | <25s |
| High (Pixel 7, OnePlus 11) | <12s |

## Monetization Tiers

| Tier | Price | Limits |
|------|-------|--------|
| Free | ₹0 (AdMob) | 4 styles, 10 tracks, 720p, watermark, 3 videos/day |
| Pro Monthly | ₹299/mo | All 12 styles, 50 tracks, 720p, no watermark, 3 branding presets |
| Pro Yearly | ₹1,999/yr | Same as Pro Monthly |
| Business | ₹999/mo or ₹7,999/yr | Everything + 1080p + 60s + batch mode + multi-format export |

**Free trial:** 3-day Pro on first install, no credit card required.

**Ad placements (free tier only):**
- Interstitial after every 3rd export
- Native ad strip on gallery picker screen
- No ads during editing flow, rendering, or preview

## Branding Strip

- One-time setup: logo (PNG/JPG), business name, phone, optional address
- Auto-burned as bottom strip (10% frame height, semi-transparent) on every video
- Toggle on/off per video
- Paid: 3 branding presets ("Shop 1", "Shop 2", "Event mode")

## Text Overlay

- Headline: max 60 chars | Subtext: max 100 chars (optional)
- 8 fonts: 4 Devanagari (Noto Sans Devanagari variants) + 4 Latin
- Auto-color: text color selected by background brightness for legibility
- Text animation is part of the chosen motion style — not a separate user choice

## Music Library

- 50 royalty-free tracks bundled as app assets, 30s each, ~6–8 MB total
- Categories: Upbeat (15), Devotional (10), Festive (10), Calm (10), Sound Effects (5)
- Licensed once (Artlist / Epidemic Sound) — not streamed
- User can also pick from device MP3 files

## Localization

- **Hindi is the default** on first launch (locale detection)
- English available as user setting
- Use Flutter's `intl` + ARB files: `app_hi.arb`, `app_en.arb`
- All UI translated: buttons, onboarding, errors, paywall screens

## What We Don't Build (MVP Hard Constraints)

- No timeline editor, keyframes, multi-layer editing
- No stock photo/video library, sticker packs, GIF overlays, filters
- No cloud sync, user accounts, login
- No social/community features
- No analytics integration with WhatsApp Business
- No scheduled posting
- No languages beyond Hindi + English in MVP

## Build & Run

```bash
# Get dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build Android APK
flutter build apk --release

# Build Android App Bundle (Play Store)
flutter build appbundle --release

# Build iOS (when ready)
flutter build ios --release
```

Requires Flutter 3.x stable. For `ffmpeg_kit_flutter`, use the LGPL variant.

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/theme/app_theme.dart` | ThemeData, color tokens, text styles |
| `lib/engine/motion_style_engine.dart` | Core: JSON spec → FFmpeg command |
| `lib/features/editor/editor_screen.dart` | Main editing screen + live preview |
| `lib/features/export/export_screen.dart` | Render progress + share |
| `lib/data/db/app_database.dart` | Drift DB setup |
| `lib/billing/billing_manager.dart` | Subscription state + paywall gating |
| `assets/motion_styles/styles.json` | Motion style specs |
| `assets/music/` | 50 bundled royalty-free tracks |

## Play Store Identity

- **App name:** StatusPro: Status Video Maker
- **Package:** `com.binaryscript.statuspro`
- **Short description:** "Make WhatsApp Status videos for your shop, daily offers & promos in 60s."
- **Target keywords:** WhatsApp status video maker, business status video, offer video maker, dukaan status

## Post-MVP Roadmap

- v1.1: +4 motion styles, Poster mode, Portuguese + Bahasa localization, iOS launch
- v1.2: Batch mode, product catalog mode, Tamil + Telugu UI
- v2.0: StatusPro suite — Poster, Broadcast, Catalog, Invoice apps
