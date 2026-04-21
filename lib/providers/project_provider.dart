import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../data/models/export_format.dart';
import '../data/models/motion_style.dart';
import '../data/models/video_project.dart';

class ProjectNotifier extends StateNotifier<VideoProject?> {
  ProjectNotifier() : super(null);

  void startNew(List<String> assetPaths) {
    state = VideoProject.create(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      assetPaths: assetPaths,
    ).copyWithMusic(AppConstants.defaultMusicTrackId);
  }

  void loadFrom(VideoProject project) => state = project;

  void setMotionStyle(MotionStyleId id) {
    if (state == null) return;
    state = state!.copyWith(motionStyleId: id);
  }

  void setExportFormat(ExportFormat format) {
    if (state == null) return;
    state = state!.copyWith(exportFormat: format);
  }

  void setFrameCaption(int index, String caption) {
    if (state == null) return;
    state = state!.withFrameCaption(index, caption);
  }

  void setFramePriceTag(int index, String price) {
    if (state == null) return;
    state = state!.withFramePriceTag(index, price);
  }

  void setFrameMrpTag(int index, String mrp) {
    if (state == null) return;
    state = state!.withFrameMrpTag(index, mrp);
  }

  void setFrameOfferBadge(int index, String badge) {
    if (state == null) return;
    state = state!.withFrameOfferBadge(index, badge);
  }

  void setFrameDuration(int index, int seconds) {
    if (state == null) return;
    state = state!.withFrameDuration(index, seconds);
  }

  void setFrameTextPosition(int index, String position) {
    if (state == null) return;
    state = state!.withFrameTextPosition(index, position);
  }

  void setFrameBadgeSize(int index, String size) {
    if (state == null) return;
    state = state!.withFrameBadgeSize(index, size);
  }

  void setFrameBgRemoval(int index, bool enabled) {
    if (state == null) return;
    state = state!.withFrameBgRemoval(index, enabled);
  }

  void setFrameBgColor(int index, int argb) {
    if (state == null) return;
    state = state!.withFrameBgColor(index, argb);
  }

  void reorderFrames(int oldIndex, int newIndex) {
    if (state == null) return;
    if (oldIndex < newIndex) newIndex--;
    state = state!.reorderFrames(oldIndex, newIndex);
  }

  void duplicateFrame(int index) {
    if (state == null) return;
    if (state!.assetPaths.length >= 10) return; // max 10 slides
    state = state!.duplicateFrame(index);
  }

  void removeFrame(int index) {
    if (state == null || state!.assetPaths.length <= 1) return;
    state = state!.removeFrame(index);
  }

  void addTextSlide({int? afterIndex}) {
    if (state == null) return;
    if (state!.assetPaths.length >= 10) return;
    state = state!.insertTextSlide(afterIndex: afterIndex);
  }

  void applyTemplate({required String badge, required int duration}) {
    if (state == null) return;
    state = state!.applyTemplate(badge: badge, duration: duration);
  }

  void applyToAll({String? caption, String? priceTag, String? mrpTag, String? badge}) {
    if (state == null) return;
    final n = state!.assetPaths.length;
    if (caption  != null) state = state!.copyWith(frameCaptions:    List.filled(n, caption));
    if (priceTag != null) state = state!.copyWith(framePriceTags:   List.filled(n, priceTag));
    if (mrpTag   != null) state = state!.copyWith(frameMrpTags:     List.filled(n, mrpTag));
    if (badge    != null) state = state!.copyWith(frameOfferBadges: List.filled(n, badge));
  }

  void setMusic(String? trackId) {
    if (state == null) return;
    state = state!.copyWithMusic(trackId);
  }

  void toggleBranding(bool enabled) {
    if (state == null) return;
    state = state!.copyWith(brandingEnabled: enabled);
  }

  // ── Phase 2 ───────────────────────────────────────────────────────────────

  void setTextAnimStyle(String style) {
    if (state == null) return;
    state = state!.copyWith(textAnimStyle: style);
  }

  void setQrData(String? data) {
    if (state == null) return;
    state = state!.copyWith(qrData: data);
  }

  void setQrEnabled(bool enabled) {
    if (state == null) return;
    state = state!.copyWith(qrEnabled: enabled);
  }

  void setQrPosition(String position) {
    if (state == null) return;
    state = state!.copyWith(qrPosition: position);
  }

  void setCountdownText(String? text) {
    if (state == null) return;
    state = state!.copyWith(countdownText: text);
  }

  void setCountdownEnabled(bool enabled) {
    if (state == null) return;
    state = state!.copyWith(countdownEnabled: enabled);
  }

  void setFrameVoiceover(int frameIndex, String? path) {
    if (state == null) return;
    state = state!.withFrameVoiceover(frameIndex, path);
  }

  void setFrameDurations(List<int> durations) {
    if (state == null) return;
    state = state!.copyWith(frameDurations: durations);
  }

  void addBeforeAfterSlide(String leftPath, String rightPath,
      {int? afterIndex}) {
    if (state == null) return;
    if (state!.assetPaths.length >= 10) return;
    state = state!.insertBeforeAfterSlide(leftPath, rightPath,
        afterIndex: afterIndex);
  }

  void reset() => state = null;
}

final projectProvider = StateNotifierProvider<ProjectNotifier, VideoProject?>(
  (ref) => ProjectNotifier(),
);
