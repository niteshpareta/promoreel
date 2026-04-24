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

  /// Set just the slide-to-slide transition (one axis of the new
  /// two-axis picker). Leaves camera motion unchanged.
  void setTransition(String transitionId) {
    if (state == null) return;
    state = state!.copyWith(transitionId: transitionId);
  }

  /// Set just the per-slide camera motion. Leaves transition unchanged.
  void setCameraMotion(String cameraMotionId) {
    if (state == null) return;
    state = state!.copyWith(cameraMotionId: cameraMotionId);
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

  /// Set the trim window (in milliseconds) on a video slide. Also
  /// updates `frameDurations[index]` so the slide's on-screen time
  /// matches the trim length — current product call is "auto-match
  /// duration when trimming" (decoupling can come later if asked for).
  void setFrameVideoTrim(int index, int startMs, int endMs) {
    if (state == null) return;
    var next = state!.withFrameVideoTrim(index, startMs, endMs);
    if (endMs > startMs) {
      final durSec = ((endMs - startMs) / 1000.0).ceil().clamp(1, 60);
      next = next.withFrameDuration(index, durSec);
    }
    state = next;
  }

  void setFrameVideoRotation(int index, int degrees) {
    if (state == null) return;
    state = state!.withFrameVideoRotation(index, degrees);
  }

  void setFrameVideoUseAudio(int index, bool enabled) {
    if (state == null) return;
    state = state!.withFrameVideoUseAudio(index, enabled);
  }

  void setFrameVideoSpeed(int index, double speed) {
    if (state == null) return;
    state = state!.withFrameVideoSpeed(index, speed);
  }

  void setFrameVideoCropRect(int index,
      {required double x, required double y,
      required double w, required double h}) {
    if (state == null) return;
    state = state!.withFrameVideoCropRect(index, x: x, y: y, w: w, h: h);
  }

  void setFrameTextPosition(int index, String position) {
    if (state == null) return;
    state = state!.withFrameTextPosition(index, position);
  }

  void setFrameBadgeSize(int index, String size) {
    if (state == null) return;
    state = state!.withFrameBadgeSize(index, size);
  }

  void setFrameCaptionStyle(int index, String styleId) {
    if (state == null) return;
    state = state!.withFrameCaptionStyle(index, styleId);
  }

  /// Apply the same caption style to every frame.
  void setAllCaptionStyles(String styleId) {
    if (state == null) return;
    final n = state!.assetPaths.length;
    state = state!.copyWith(frameCaptionStyles: List.filled(n, styleId));
  }

  void setFrameCaptionFont(int index, String family) {
    if (state == null) return;
    state = state!.withFrameCaptionFont(index, family);
  }

  void setFrameCaptionTextColor(int index, int argb) {
    if (state == null) return;
    state = state!.withFrameCaptionTextColor(index, argb);
  }

  void setFrameCaptionPillColor(int index, int argb) {
    if (state == null) return;
    state = state!.withFrameCaptionPillColor(index, argb);
  }

  void setFrameCaptionEffect(int index, String effect) {
    if (state == null) return;
    state = state!.withFrameCaptionEffect(index, effect);
  }

  void setFrameCaptionUppercase(int index, bool value) {
    if (state == null) return;
    state = state!.withFrameCaptionUppercase(index, value);
  }

  void setFrameCaptionRotation(int index, int degrees) {
    if (state == null) return;
    state = state!.withFrameCaptionRotation(index, degrees);
  }

  void setFrameOfferBadgeStyle(int index, String styleId) {
    if (state == null) return;
    state = state!.withFrameOfferBadgeStyle(index, styleId);
  }

  void setFrameOfferBadgeFillColor(int index, int argb) {
    if (state == null) return;
    state = state!.withFrameOfferBadgeFillColor(index, argb);
  }

  void setFrameOfferBadgeTextColor(int index, int argb) {
    if (state == null) return;
    state = state!.withFrameOfferBadgeTextColor(index, argb);
  }

  void setFrameOfferBadgeAnim(int index, String anim) {
    if (state == null) return;
    state = state!.withFrameOfferBadgeAnim(index, anim);
  }

  /// Copy the full badge configuration (text + style preset + fill/text
  /// colour overrides + entrance animation) from frame [fromIndex] to
  /// every other frame. Used by the "Apply to all frames" link under the
  /// Badge section — mirrors `applyToAll` for captions.
  void applyBadgeToAll(int fromIndex) {
    final p = state;
    if (p == null) return;
    final n = p.assetPaths.length;
    if (fromIndex < 0 || fromIndex >= n) return;
    final text = fromIndex < p.frameOfferBadges.length
        ? p.frameOfferBadges[fromIndex]
        : '';
    final styleId = p.offerBadgeStyleIdFor(fromIndex);
    final fill = p.offerBadgeFillColorOverrideFor(fromIndex);
    final textColor = p.offerBadgeTextColorOverrideFor(fromIndex);
    final anim = p.offerBadgeAnimFor(fromIndex);
    state = p.copyWith(
      frameOfferBadges:          List.filled(n, text),
      frameOfferBadgeStyles:     List.filled(n, styleId),
      frameOfferBadgeFillColors: List.filled(n, fill),
      frameOfferBadgeTextColors: List.filled(n, textColor),
      frameOfferBadgeAnims:      List.filled(n, anim),
    );
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
