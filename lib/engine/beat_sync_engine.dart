import '../data/services/music_library.dart';

class BeatSyncEngine {
  /// Given a music track and slide count, returns per-slide durations (seconds)
  /// that sum to exactly [totalSeconds] and align to beat boundaries.
  static List<int> calculate({
    required String musicTrackId,
    required int slideCount,
    int totalSeconds = 30,
  }) {
    if (slideCount <= 0) return [];

    final track = MusicLibrary.findById(musicTrackId);
    final bpm = track?.bpm;

    if (bpm == null || bpm <= 0) {
      // No BPM info — evenly distribute
      final base = totalSeconds ~/ slideCount;
      final remainder = totalSeconds % slideCount;
      return List.generate(slideCount, (i) => i < remainder ? base + 1 : base);
    }

    // Beat interval in seconds
    final beatSec = 60.0 / bpm;

    // Total beats available
    final totalBeats = totalSeconds / beatSec;

    // Beats per slide — round to nearest even number (cuts sound better on even beats)
    int beatsPerSlide = (totalBeats / slideCount).round();
    beatsPerSlide = (beatsPerSlide / 2).round() * 2; // snap to even
    beatsPerSlide = beatsPerSlide.clamp(2, 8);

    // Convert to seconds, ensure minimum 1s
    final secPerSlide = (beatSec * beatsPerSlide).round().clamp(1, 10);

    // Build durations and adjust last slide to hit exactly totalSeconds
    final durations = List.filled(slideCount, secPerSlide);
    final sum = durations.fold(0, (a, b) => a + b);
    final diff = totalSeconds - sum;
    durations[slideCount - 1] = (durations[slideCount - 1] + diff).clamp(1, 30);

    return durations;
  }
}
