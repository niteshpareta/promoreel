# PromoReel — Business Video Maker

Offline-first Flutter app that lets small business owners, entrepreneurs, and creators make professional 30-second vertical promo videos — ready to share on WhatsApp Status, Instagram Reels, Facebook, and YouTube Shorts — in under 90 seconds.

- **Scope:** global product
- **Launch:** India-first (Google Play, English + Hindi) → global rollout in v1.1 → iOS in v2
- **Package:** `com.binaryscript.promoreel`
- **Owner:** BinaryScript (nk92.iit@gmail.com)

See [`CLAUDE.md`](./CLAUDE.md) for the full product spec, tech stack, motion-style engine, output specs, monetization tiers, and roadmap. See [`PLAYSTORE_LISTING.txt`](./PLAYSTORE_LISTING.txt) for the authoritative India launch store copy.

## Build & Run

```bash
flutter pub get
flutter run                          # run on connected device / emulator
flutter build apk --release          # Android APK
flutter build appbundle --release    # Google Play AAB
flutter build ios --release          # iOS (v2)
```

Requires Flutter 3.x stable. Uses the LGPL variant of `ffmpeg_kit_flutter`.
