# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product positioning (read first)

**PromoReel is a global product with an India-first v1.0 launch.**
- Scope: a business video maker for small-business owners, solo entrepreneurs, service providers (salons, clinics, restaurants), small institutions (coaching, real estate, event organisers), and D2C creators — worldwide. It is **not** a WhatsApp-Status-only app and **not** shop-only. WhatsApp Status is one supported distribution target alongside Instagram Reels, Facebook, and YouTube Shorts.
- Launch sequence: Google Play India v1.0 (en + hi) → global rollout in v1.1+ (en-US, id, pt-BR, es) → iOS in v2.
- Default UI language: **English**. Hindi auto-selects only when the device locale is `hi-*`. Do not treat the app as "Hindi-first".
- The "Rajesh" persona (tier-2 Indian shop owner on WhatsApp Business) is the anchor for v1.0 design calls because India is the beachhead — not because the product is India-only.

The authoritative India store-copy source is `PLAYSTORE_LISTING.txt`. A separate global en-US listing will be authored in v1.1.

## What this app is

**Offline-first Flutter app for small-business owners** that assembles a sequence of photos / short videos + per-frame captions, price tags, and offer badges into a vertical (or square / landscape) promo video ready to share on WhatsApp Status, Instagram Reels, Facebook, and YouTube Shorts. All rendering happens on-device via FFmpeg. No cloud, no accounts, no stock library.

> **Naming:** `pubspec.yaml` name is `promoreel`, package ID is `com.binaryscript.promoreel`, Play Store title is `PromoReel-Business Video Maker`. The Flutter app title, DB filename (`promorreel_history.db` — triple "r" typo baked in), temp folder (`promorreel_render`), and output directory all say "PromoReel". The `StatusProStatusVideoMaker` folder name at the repo root is a legacy remnant of the pre-rebrand identity — treat it as stale, don't "fix" paths to match it.

## Commands

```bash
flutter pub get                      # dependencies
flutter run                          # run on connected device / emulator
flutter analyze                      # lint (uses flutter_lints via analysis_options.yaml)
flutter test                         # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter build apk --release          # Android APK
flutter build appbundle --release    # Play Store AAB
```

Dart SDK: `^3.9.2`. Flutter 3.x stable. Requires `ffmpeg_kit_flutter_new` (the actively-maintained fork of the archived `ffmpeg_kit_flutter`).

## Architecture — the part worth reading before editing

### The export pipeline is the whole app

`MediaEncoder.export()` in `lib/engine/media_encoder.dart` is the core. Every feature is plumbing that feeds a `VideoProject` into this function. The pipeline (in order):

1. **Resolve assets** — each slide in `project.assetPaths` is either a real file path, the sentinel `kTextSlide` (`__text__`), or a before/after split path (`__ba__:leftPath|rightPath`). `isVideoFlags` is derived from extension.
2. **Pre-composite stills on a Flutter canvas → PNG** (`_compositeImage`, `_compositeTextSlide`, `_compositeBeforeAfter`). This is the key perf move: instead of asking FFmpeg to blur-background+letterbox every still, Flutter paints each still to an exact `outW×outH` PNG with a blurred-cover background (or black for portraits, gradient for text slides). FFmpeg then just `fps=30,format=yuv420p`s them — no split/blur/scale/overlay cost.
3. **Render text overlays in parallel** — `TextRenderer.renderToFile` paints each frame's caption + price + MRP + offer badge to a transparent 720×1280 PNG. One PNG per frame that has any text.
4. **Render decorators as PNGs** — branding strip (`BrandingCompositor`), countdown banner (`_renderCountdown`), QR code (`_renderQr`, via `qr_flutter`), watermark (`_renderWatermark`). All are full-frame transparent PNGs positioned by drawing into the canvas at the right coords, not by ffmpeg x/y math.
5. **Extract music from bundle** — asset mp3s must be copied from `rootBundle` to a temp file before FFmpeg can read them. `frameVoiceovers` are already file paths (recorded via `record` package).
6. **`MotionStyleEngine.build(...)` generates the ffmpeg command string.** It is NOT 12 custom filter graphs — it's a single parameterized builder that picks an xfade `transition=` + `duration=` per `MotionStyleId` (see `_specs` map). All 12 "motion styles" currently differ only in those two values. If real per-style geometry is needed, that's where it goes.
7. **`FFmpegKit.executeAsync`** runs it with progress callbacks, then `VideoThumbnail.thumbnailFile` + `VideoHistoryService.insert` persist the result.

**Invariant:** the xfade chain assumes each input's trimmed length is `frameDuration + trans` (except the last). If you change how durations are computed, update both the `-t` for the input AND the `offset=` on the xfade filter — they're coupled at `MotionStyleEngine.build` lines ~75–165.

**Invariant:** voice-over audio timing subtracts `(frameIdx - 1) * trans` because xfade compresses the absolute timeline — each transition after the first shaves `trans` seconds off every downstream frame's start. See `activeVoiceovers` correction logic.

### State model — per-frame parallel arrays

`VideoProject` (`lib/data/models/video_project.dart`) holds the whole editor state as **parallel arrays indexed by slide position**: `assetPaths`, `frameCaptions`, `framePriceTags`, `frameMrpTags`, `frameOfferBadges`, `frameDurations`, `frameTextPositions`, `frameBadgeSizes`, `frameVoiceovers`. Structural mutations (`removeFrame`, `duplicateFrame`, `reorderFrames`, `_insertSlide`) must mutate **all** arrays together — `_rebuild` exists to make that obvious. `copyWith` uses a `_sentinel` for nullable fields (`qrData`, `countdownText`) so callers can distinguish "leave unchanged" from "set to null".

Two sentinel path formats live in `assetPaths`:
- `kTextSlide = '__text__'` — renders a gradient background
- `kBeforeAfterPrefix = '__ba__:'` followed by `leftPath|rightPath` — renders a split-screen composite

Both are handled in `MediaEncoder._compositeImage`/`_compositeTextSlide`/`_compositeBeforeAfter`, not by FFmpeg.

### State management

Riverpod (plain `flutter_riverpod` — no code-gen). Providers live in `lib/providers/`:
- `projectProvider` — the single active `VideoProject?` being edited. `ProjectNotifier` has one mutator per field; prefer these over manual `copyWith` in UI.
- `subscriptionProvider` — **defaults to `SubscriptionTier.business` in dev** so all paywalled features are unlocked. Before shipping, change `SubscriptionNotifier()` initial state to `SubscriptionTier.free` and wire it to real `in_app_purchase` state.
- `draftsProvider`, `historyProvider`, `brandingProvider` — sqflite-backed, see below.

### Persistence

**One SQLite file, `promorreel_history.db`** (note: triple "r" typo is intentional and baked in — don't rename it without a migration). Two tables:
- `videos` — export history (used on home screen).
- `drafts` — in-progress `VideoProject` serialized as `project_json`.

Managed by `DraftService` and `VideoHistoryService` directly (raw sqflite, no ORM). Branding presets live in `shared_preferences` via `BrandingService`.

### Routing

`GoRouter` in `lib/core/router/app_router.dart`. `buildRouter(showOnboarding:)` is called once from `PromoReelApp`; `showOnboarding` is determined in `main.dart` from a `SharedPreferences` flag (`onboarding_seen`). All routes are flat (no nested shells).

The full wizard flow: `/picker → /caption-wizard → /style-picker → /review → /export`. `/editor` is a standalone entry for editing a loaded draft. `/paywall?tier=pro|business` is opened from any gated CTA. `/player?path=...` plays an exported mp4.

### Gallery picker

`/picker` is a thin bridge to the system Android Photo Picker via `image_picker.pickMultipleMedia()`. It renders a loading spinner, triggers the system picker in `initState`, and `pushReplacement`s to `/editor` with the selected file paths (so Back from editor doesn't re-launch the picker). No `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` permissions are declared — this was an intentional Play Store Photo & Video Permissions policy decision (see the `Migrate gallery picker to Android Photo Picker` commit). On Android 13+ the native Photo Picker opens with zero permission prompts; on Android 11–12 with the Play Services MediaProvider backport the same flow works; on older devices without the backport it falls back to `ACTION_GET_CONTENT` (suboptimal but acceptable).

### Subscription gating

`SubscriptionTierX` extension in `subscription_provider.dart` is the single source of truth for what each tier unlocks (`has1080p`, `hasQrCode`, `hasBeatSync`, `maxMotionStyles`, etc.). UI should read capability flags from the tier, not check `tier == SubscriptionTier.business` directly, so gating rules stay in one place.

`MotionStyle.all[i].isPro` marks free vs pro styles — free tier currently has 4 styles (first 2 of subtle + first 2 of energetic family); the rest require Pro.

## Key files

| File | Purpose |
|------|---------|
| `lib/engine/media_encoder.dart` | Top-level export orchestrator. Read this first. |
| `lib/engine/motion_style_engine.dart` | FFmpeg command builder. All xfade / overlay math. |
| `lib/engine/text_renderer.dart` | Per-frame caption/price/badge PNG rasterizer. |
| `lib/engine/branding_compositor.dart` | Bottom-strip branding PNG. |
| `lib/engine/beat_sync_engine.dart` | BPM → per-slide duration allocator. |
| `lib/data/models/video_project.dart` | Per-frame parallel-array state model + sentinels. |
| `lib/data/services/draft_service.dart` | sqflite drafts + schema. |
| `lib/providers/subscription_provider.dart` | Tier capability flags (single source for gating). |
| `lib/core/constants/app_constants.dart` | Output dimensions, limits, asset paths. |
| `assets/music/` | 40 bundled MP3s loaded via `rootBundle`. |
| `PLAYSTORE_LISTING.txt` | Authoritative India (en-IN + hi-IN) Play Store copy. |

## Conventions that are not obvious from the code

- **FFmpeg commands are logged to stdout** (`print('[MediaEncoder] command: $command')`). When debugging an export failure, the command string is what you want — `session.getOutput()` is also printed on non-zero return codes.
- **Temp dir is `promorreel_render`** under `getTemporaryDirectory()`; export output goes to `Movies/PromoReel` on external storage (falls back to app documents). The Android-data path stripping in `_outputDir` is intentional — it escapes the app sandbox so the Gallery picks up the file.
- **`audioplayers` is for in-app music preview only.** Final video audio goes through FFmpeg.
- **`dependency_overrides` pins `record_platform_interface: 1.2.0`** — the `record` package's own constraint is broken on current Flutter, so don't remove the override without verifying voice-over recording still works.
- **Orientation is locked to portrait** in `app.dart`'s `MaterialApp.builder` (even though export supports landscape output format — that's a different concern).

## What is intentionally NOT in the codebase

- No timeline/keyframe editor — editing is per-frame only.
- No `drift`, no `lottie`, no Google Fonts package. Firebase scaffolding files exist (`firebase_options.dart`, `firebase.json`, iOS Podfile) but no Firebase SDK is wired into `main.dart` or `pubspec.yaml` yet — setup is only half-done.
- No iOS-specific code yet (Android is the launch target; iOS arrives in v2).
- No Hindi ARB files yet despite the positioning section — all strings are hardcoded English currently. Hindi auto-select requires these to land before first launch.
- No `photo_manager`, no `permission_handler`, no `device_info_plus` — removed with the Photo Picker migration. Don't re-add them without revisiting the Play Store photo/video permissions policy.
