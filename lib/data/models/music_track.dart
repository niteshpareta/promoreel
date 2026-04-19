enum MusicCategory { upbeat, devotional, festive, calm, soundEffects }

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.category,
    required this.assetPath,
    this.durationSeconds = 30,
    this.isPro = false,
    this.bpm,
  });

  final String id;
  final String nameEn;
  final String nameHi;
  final MusicCategory category;
  final String assetPath;
  final int durationSeconds;
  final bool isPro;
  final int? bpm;
}
