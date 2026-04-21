/// When false, all paywall gating is bypassed and Pro/lock UI is hidden.
/// Flip to true once the Google Play subscription flow is wired up.
const bool kSubscriptionEnabled = false;

abstract final class AppConstants {
  // Default music track assigned to new projects (must exist in assets/music/).
  static const String defaultMusicTrackId = 'upbeat_01';

  // Output specs
  static const int outputWidth = 720;
  static const int outputHeight = 1280;
  static const int outputWidthHd = 1080;
  static const int outputHeightHd = 1920;
  static const int outputBitrate = 2000000; // 2 Mbps
  static const int outputDuration = 30; // seconds
  static const int outputDurationLong = 60; // seconds (paid)
  static const int outputMaxFileSizeMb = 16;
  static const int outputFps = 30;

  // Asset limits
  static const int maxAssetsPerVideo = 10;
  static const int maxHeadlineChars = 60;
  static const int maxSubtextChars = 100;

  // Free tier limits
  static const int freeVideosPerDay = 3;
  static const int freeMotionStyles = 4;
  static const int freeMusicTracks = 10;

  // Music library
  static const int totalMusicTracks = 50;
  static const String musicAssetPath = 'assets/music/';

  // Motion styles
  static const String motionStylesAssetPath = 'assets/motion_styles/styles.json';
  static const int totalMotionStyles = 12;

  // Gallery folder name
  static const String galleryFolderName = 'PromoReel';

  // Branding
  static const double brandingStripHeightRatio = 0.10; // 10% of frame height

  // Export
  static const String tempFolderName = 'promoreel_temp';
}
