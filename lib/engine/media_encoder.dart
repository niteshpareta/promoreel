import 'dart:async';
import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../data/services/background_removal_service.dart';
import '../data/models/branding_preset.dart';
import '../data/models/badge_style.dart';
import '../data/models/caption_style.dart';
import '../data/models/export_format.dart';
import '../data/models/video_project.dart';
import '../data/services/music_library.dart';
import '../data/services/video_history_service.dart';
import 'branding_compositor.dart';
import 'motion_style_engine.dart';
import 'text_renderer.dart';

class ExportResult {
  const ExportResult.success(this.outputPath)
      : error = null,
        success = true;
  const ExportResult.failure(this.error)
      : outputPath = null,
        success = false;

  final bool success;
  final String? outputPath;
  final String? error;
}

class MediaEncoder {
  MediaEncoder._();

  static Future<String> _tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'promoreel_render'));
    await dir.create(recursive: true);
    return dir.path;
  }

  static Future<String> _outputDir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    var path = base.path;
    final androidIdx = path.indexOf('/Android/data/');
    if (androidIdx >= 0) path = path.substring(0, androidIdx);
    final dir = Directory(p.join(path, 'Movies', 'PromoReel'));
    await dir.create(recursive: true);
    return dir.path;
  }

  // Renders a text-only slide background (gradient) as a PNG.
  static Future<String> _compositeTextSlide(
      String outPath, double W, double H) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69), Color(0xFF0F0630)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), paint);

    final logoPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(W / 2, H / 2), W * 0.22, logoPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), H.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (data == null) throw StateError('Failed to render text slide');
    await File(outPath).writeAsBytes(data.buffer.asUint8List());
    return outPath;
  }

  // Pre-composite a before/after split-screen PNG.
  static Future<String> _compositeBeforeAfter(
      String leftPath, String rightPath, String outPath,
      {double W = 720, double H = 1280}) async {
    final leftBytes  = await File(leftPath).readAsBytes();
    final rightBytes = await File(rightPath).readAsBytes();

    final leftCodec  = await ui.instantiateImageCodec(leftBytes);
    final rightCodec = await ui.instantiateImageCodec(rightBytes);
    final leftImg  = (await leftCodec.getNextFrame()).image;
    final rightImg = (await rightCodec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
        Paint()..color = Colors.black);

    // Left half
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, W / 2, H));
    final lw = leftImg.width.toDouble(), lh = leftImg.height.toDouble();
    final lScale = (W / 2) / lw > H / lh ? (W / 2) / lw : H / lh;
    canvas.drawImageRect(
      leftImg,
      Rect.fromLTWH(0, 0, lw, lh),
      Rect.fromLTWH((W / 2 - lw * lScale) / 2, (H - lh * lScale) / 2,
          lw * lScale, lh * lScale),
      Paint(),
    );
    canvas.restore();

    // Right half
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(W / 2, 0, W / 2, H));
    final rw = rightImg.width.toDouble(), rh = rightImg.height.toDouble();
    final rScale = (W / 2) / rw > H / rh ? (W / 2) / rw : H / rh;
    canvas.drawImageRect(
      rightImg,
      Rect.fromLTWH(0, 0, rw, rh),
      Rect.fromLTWH(W / 2 + (W / 2 - rw * rScale) / 2,
          (H - rh * rScale) / 2, rw * rScale, rh * rScale),
      Paint(),
    );
    canvas.restore();

    // Divider line
    canvas.drawLine(Offset(W / 2, 0), Offset(W / 2, H),
        Paint()..color = Colors.white..strokeWidth = 3);

    // BEFORE / AFTER labels
    void drawLabel(String text, Offset offset) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: W / 2 - 20);
      tp.paint(canvas, offset);
    }

    final labelY = H * 0.86;
    drawLabel('BEFORE', Offset(16, labelY));
    drawLabel('AFTER',  Offset(W / 2 + 16, labelY));

    leftImg.dispose();
    rightImg.dispose();

    final picture    = recorder.endRecording();
    final composited = await picture.toImage(W.toInt(), H.toInt());
    final data = await composited.toByteData(format: ui.ImageByteFormat.png);
    composited.dispose();

    if (data == null) throw StateError('Failed to composite before/after');
    await File(outPath).writeAsBytes(data.buffer.asUint8List());
    return outPath;
  }

  // Pre-composite a still image to outW×outH PNG.
  static Future<String> _compositeImage(
      String srcPath, String outPath,
      {double W = 720, double H = 1280}) async {

    final bytes = await File(srcPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src   = frame.image;

    final sw = src.width.toDouble();
    final sh = src.height.toDouble();
    final aspectRatio = sw / sh;

    final isPortrait = aspectRatio <= 0.60;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    if (isPortrait) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, W, H),
        Paint()..color = Colors.black,
      );
      final fgScale = min(W / sw, H / sh);
      final fgW = sw * fgScale;
      final fgH = sh * fgScale;
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, sw, sh),
        Rect.fromLTWH((W - fgW) / 2, (H - fgH) / 2, fgW, fgH),
        Paint(),
      );
    } else {
      final bgScale = (W / sw) > (H / sh) ? (W / sw) : (H / sh);
      final bgW = sw * bgScale;
      final bgH = sh * bgScale;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, W, H));
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, sw, sh),
        Rect.fromLTWH((W - bgW) / 2, (H - bgH) / 2, bgW, bgH),
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
              sigmaX: 18, sigmaY: 18, tileMode: TileMode.clamp),
      );
      canvas.restore();

      final fgScale = min(W / sw, H / sh);
      final fgW = sw * fgScale;
      final fgH = sh * fgScale;
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, sw, sh),
        Rect.fromLTWH((W - fgW) / 2, (H - fgH) / 2, fgW, fgH),
        Paint(),
      );
    }

    src.dispose();

    final picture    = recorder.endRecording();
    final composited = await picture.toImage(W.toInt(), H.toInt());
    final data = await composited.toByteData(format: ui.ImageByteFormat.png);
    composited.dispose();

    if (data == null) throw StateError('Failed to composite image: $srcPath');
    await File(outPath).writeAsBytes(data.buffer.asUint8List());
    return outPath;
  }

  // Renders a QR code PNG positioned in the specified corner (transparent elsewhere).
  static Future<String> _renderQr(
      String data, String outPath, String position,
      {double outW = 720, double outH = 1280}) async {
    const double qrSize = 160;
    const double margin = 24;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

    double qrX, qrY;
    switch (position) {
      case 'bottom_left':  qrX = margin; qrY = outH - qrSize - margin; break;
      case 'top_right':    qrX = outW - qrSize - margin; qrY = margin; break;
      case 'top_left':     qrX = margin; qrY = margin; break;
      default: // bottom_right
        qrX = outW - qrSize - margin;
        qrY = outH - qrSize - margin;
    }

    // White rounded background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(qrX - 8, qrY - 8, qrSize + 16, qrSize + 16),
        const Radius.circular(14),
      ),
      Paint()..color = Colors.white,
    );

    // QR painter
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
      dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000)),
    );
    canvas.save();
    canvas.translate(qrX, qrY);
    painter.paint(canvas, Size(qrSize, qrSize));
    canvas.restore();

    final picture = recorder.endRecording();
    final img  = await picture.toImage(outW.toInt(), outH.toInt());
    final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    if (pngData == null) throw StateError('Failed to render QR code');
    await File(outPath).writeAsBytes(pngData.buffer.asUint8List());
    return outPath;
  }

  // Renders a countdown/urgency banner PNG at the top of the frame.
  static Future<String> _renderCountdown(
      String text, String outPath,
      {double outW = 720, double outH = 1280}) async {
    const double bannerH = 76;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFFF6D00)],
      ).createShader(Rect.fromLTWH(0, 0, outW, bannerH));
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, bannerH), bgPaint);

    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '⏰  ',
            style: TextStyle(fontSize: 24, color: Colors.white),
          ),
          TextSpan(
            text: text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: outW - 32);
    tp.paint(canvas, Offset((outW - tp.width) / 2, (bannerH - tp.height) / 2));

    final picture = recorder.endRecording();
    final img  = await picture.toImage(outW.toInt(), outH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    if (data == null) throw StateError('Failed to render countdown');
    await File(outPath).writeAsBytes(data.buffer.asUint8List());
    return outPath;
  }

  static Future<String> _renderWatermark(String outPath) async {
    const double W = 720, H = 1280;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, H - 46, 230, 32),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'Made with PromoReel',
        style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: 300);
    tp.paint(canvas, const Offset(22, H - 38));

    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), H.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    if (data == null) throw StateError('Failed to render watermark');
    await File(outPath).writeAsBytes(data.buffer.asUint8List());
    return outPath;
  }

  static Future<ExportResult> _runFFmpeg(
    String command,
    String outputPath,
    String tmp,
    int totalDuration,
    void Function(double)? onProgress, {
    Map<String, dynamic>? projectJson,
  }) async {
    // ignore: avoid_print
    print('[MediaEncoder] command: $command');
    final totalMs = totalDuration * 1000.0;
    final completer = Completer<ExportResult>();

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          String thumbnailPath = '';
          try {
            final thumb = await VideoThumbnail.thumbnailFile(
              video: outputPath,
              thumbnailPath: tmp,
              imageFormat: ImageFormat.JPEG,
              maxHeight: 320,
              quality: 70,
            );
            if (thumb != null) thumbnailPath = thumb;
          } catch (_) {}

          await VideoHistoryService().insert(
            outputPath: outputPath,
            thumbnailPath: thumbnailPath,
            durationSeconds: totalDuration,
            projectJson: projectJson,
          );
          completer.complete(ExportResult.success(outputPath));
        } else {
          final logs = await session.getOutput() ?? '';
          // Write the FULL FFmpeg output to a file so we can inspect it
          // later — logcat truncates individual print() calls at ~4 KB,
          // which hides the actual failure reason on complex filter graphs.
          try {
            final dumpPath = p.join(tmp, 'ffmpeg_last_error.txt');
            await File(dumpPath).writeAsString(logs);
            // ignore: avoid_print
            print('[MediaEncoder] FAILED — full log at: $dumpPath');
          } catch (_) {}
          // ignore: avoid_print
          print('[MediaEncoder] FAILED (truncated):\n${logs.substring(
              logs.length > 3000 ? logs.length - 3000 : 0)}');
          final errorLine = logs
                  .split('\n')
                  .where((l) =>
                      l.contains('Error') ||
                      l.contains('No such file') ||
                      l.contains('Invalid') ||
                      l.contains('error'))
                  .firstOrNull ??
              'Export failed';
          completer.complete(ExportResult.failure(errorLine));
        }
      },
      null,
      (statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && totalMs > 0) {
          onProgress?.call((timeMs / totalMs).clamp(0.0, 0.95));
        }
      },
    );

    return completer.future;
  }

  static Future<ExportResult> export({
    required VideoProject project,
    required BrandingPreset? branding,
    void Function(double progress)? onProgress,
    bool addWatermark = false,
    ExportQuality quality = ExportQuality.fullHd,
  }) async {
    final tmp = await _tempDir();
    final out = await _outputDir();
    final ts  = DateTime.now().millisecondsSinceEpoch;

    final brandingPngPath = p.join(tmp, 'branding_$ts.png');
    final outputPath      = p.join(out, 'status_$ts.mp4');

    final renderedTextPngs    = <String>[];
    final compositeImagePaths = <String>[];
    String? brandingPath;
    String? extractedAudioPath;
    String? watermarkPngPath;
    String? countdownPngPath;
    String? qrPngPath;

    try {
      final n = project.assetPaths.length;
      final fmt  = project.exportFormat;
      final outW = fmt.outWidthFor(quality).toInt();
      final outH = fmt.outHeightFor(quality).toInt();

      // 1. Use frame durations exactly as set by the user — no scaling
      final rawDurations = List<int>.generate(n, (i) =>
          i < project.frameDurations.length ? project.frameDurations[i] : 3);
      final totalDuration = rawDurations.fold(0, (a, b) => a + b);
      final frameDurationsDouble = rawDurations.map((d) => d.toDouble()).toList();

      final List<double> frameStarts = [];
      double cum = 0;
      for (int i = 0; i < n; i++) {
        frameStarts.add(cum);
        cum += frameDurationsDouble[i];
      }

      // 2. Resolve asset paths — text slides and before/after are always valid
      final resolvedPaths     = <String>[];
      final isVideoFlags      = <bool>[];
      final resolvedDurations = <double>[];

      for (int i = 0; i < project.assetPaths.length; i++) {
        final path = project.assetPaths[i];
        final dur  = i < frameDurationsDouble.length
            ? frameDurationsDouble[i] : 3.0;

        if (path == kTextSlide) {
          resolvedPaths.add(kTextSlide);
          isVideoFlags.add(false);
          resolvedDurations.add(dur);
        } else if (isBeforeAfterPath(path)) {
          final parts = decodeBeforeAfter(path);
          // Include if at least one side exists
          if (await File(parts[0]).exists() || await File(parts[1]).exists()) {
            resolvedPaths.add(path);
            isVideoFlags.add(false);
            resolvedDurations.add(dur);
          }
        } else if (await File(path).exists()) {
          resolvedPaths.add(path);
          final ext = p.extension(path).toLowerCase();
          isVideoFlags.add(['.mp4', '.mov', '.3gp', '.mkv'].contains(ext));
          resolvedDurations.add(dur);
        }
      }

      if (resolvedPaths.isEmpty) {
        return const ExportResult.failure('No valid media files found.');
      }

      // 3. Pre-composite still images in Flutter.
      //    Text slides → gradient PNG.
      //    Before/after → split-screen PNG.
      //    Portrait images → no blur needed.
      //    When `frameBgRemoval[i]` is set, first run the image through
      //    Subject Segmentation to drop the background, then composite.
      final preComposedPaths = List<String?>.filled(resolvedPaths.length, null);
      final compositeTasks   = <Future<void>>[];

      for (int i = 0; i < resolvedPaths.length; i++) {
        if (!isVideoFlags[i]) {
          final outPng = p.join(tmp, 'composed_${i}_$ts.png');
          compositeImagePaths.add(outPng);
          final idx  = i;
          String path = resolvedPaths[i];

          // Background removal — only for regular image assets (not text or
          // before/after). Synchronous in the loop so each frame finishes its
          // cutout before the composite task spawns.
          if (path != kTextSlide &&
              !isBeforeAfterPath(path) &&
              project.bgRemovalFor(i)) {
            final argb = project.bgColorFor(i);
            // 0 means "use the brand ember colour" — ARGB 0xFFF2A848 matches
            // AppColors.brandEmber. Kept as a literal here so the engine
            // layer doesn't depend on the UI theme tokens.
            final bgArgb = argb == 0 ? 0xFFF2A848 : argb;
            final cutout = await BackgroundRemovalService.processToPath(
              inputPath: path,
              backgroundColorArgb: bgArgb,
            );
            if (cutout != null) path = cutout;
          }

          Future<String> task;
          if (path == kTextSlide) {
            task = _compositeTextSlide(
                outPng, outW.toDouble(), outH.toDouble());
          } else if (isBeforeAfterPath(path)) {
            final parts = decodeBeforeAfter(path);
            final left  = await File(parts[0]).exists()
                ? parts[0] : parts[1];
            final right = await File(parts[1]).exists()
                ? parts[1] : parts[0];
            task = _compositeBeforeAfter(left, right, outPng,
                W: outW.toDouble(), H: outH.toDouble());
          } else {
            task = _compositeImage(path, outPng,
                W: outW.toDouble(), H: outH.toDouble());
          }
          compositeTasks.add(task.then((v) => preComposedPaths[idx] = v));
        }
      }

      await Future.wait(compositeTasks);

      final finalInputPaths = <String>[];
      for (int i = 0; i < resolvedPaths.length; i++) {
        finalInputPaths.add(preComposedPaths[i] ?? resolvedPaths[i]);
      }

      // 4. Render text overlay PNGs in parallel
      final textOverlays = <FrameTextOverlay>[];
      final renderTasks  = <({
        int i, String caption, String price, String mrp,
        String badge, String position, String badgeSize,
        CaptionStyle captionStyle, BadgeStyle badgeStyle,
        bool uppercase, int rotation,
        String pngPath, String animStyle
      })>[];

      final animStyle = project.textAnimStyle;

      for (int i = 0; i < n; i++) {
        final caption   = i < project.frameCaptions.length    ? project.frameCaptions[i].trim()    : '';
        final price     = i < project.framePriceTags.length   ? project.framePriceTags[i].trim()   : '';
        final mrp       = i < project.frameMrpTags.length     ? project.frameMrpTags[i].trim()     : '';
        final badge     = i < project.frameOfferBadges.length ? project.frameOfferBadges[i].trim() : '';
        if (caption.isEmpty && price.isEmpty && mrp.isEmpty && badge.isEmpty) continue;
        final position  = i < project.frameTextPositions.length ? project.frameTextPositions[i] : 'bottom';
        final badgeSize = i < project.frameBadgeSizes.length    ? project.frameBadgeSizes[i]    : 'medium';
        final resolvedStyle = project.resolvedCaptionStyleFor(i);
        final resolvedBadge = project.resolvedOfferBadgeStyleFor(i);
        final uppercase = project.captionUppercaseFor(i);
        final rotation = project.captionRotationFor(i);
        final pngPath   = p.join(tmp, 'overlay_frame_${i}_$ts.png');
        renderedTextPngs.add(pngPath);
        renderTasks.add((
          i: i, caption: caption, price: price, mrp: mrp,
          badge: badge, position: position, badgeSize: badgeSize,
          captionStyle: resolvedStyle, badgeStyle: resolvedBadge,
          uppercase: uppercase, rotation: rotation,
          pngPath: pngPath, animStyle: animStyle,
        ));
      }

      await Future.wait(renderTasks.map((t) => TextRenderer.renderToFile(
        headline: t.caption, priceTag: t.price, mrpTag: t.mrp,
        offerBadge: t.badge, textPosition: t.position,
        badgeSize: t.badgeSize, captionStyle: t.captionStyle,
        badgeStyle: t.badgeStyle,
        uppercase: t.uppercase, rotationDegrees: t.rotation,
        outputPath: t.pngPath,
      )));

      for (final t in renderTasks) {
        textOverlays.add(FrameTextOverlay(
          path:      t.pngPath,
          startSec:  frameStarts[t.i],
          endSec:    frameStarts[t.i] + frameDurationsDouble[t.i],
          animStyle: t.animStyle,
          textPosition: t.position,
        ));
      }

      // 5. Branding strip
      if (branding != null && branding.businessName.isNotEmpty) {
        await BrandingCompositor.renderToFile(
            preset: branding, outputPath: brandingPngPath);
        brandingPath = brandingPngPath;
      }

      // 5b. Countdown banner
      if (project.countdownEnabled &&
          project.countdownText != null &&
          project.countdownText!.isNotEmpty) {
        final cdPath = p.join(tmp, 'countdown_$ts.png');
        await _renderCountdown(project.countdownText!, cdPath,
            outW: outW.toDouble(), outH: outH.toDouble());
        countdownPngPath = cdPath;
      }

      // 5c. QR overlay
      if (project.qrEnabled &&
          project.qrData != null &&
          project.qrData!.isNotEmpty) {
        final qrPath = p.join(tmp, 'qr_$ts.png');
        await _renderQr(project.qrData!, qrPath, project.qrPosition,
            outW: outW.toDouble(), outH: outH.toDouble());
        qrPngPath = qrPath;
      }

      // 5d. Watermark (free tier)
      if (addWatermark) {
        final wmPath = p.join(tmp, 'watermark_$ts.png');
        await _renderWatermark(wmPath);
        watermarkPngPath = wmPath;
      }

      // 6. Audio track
      String? audioPath;
      if (project.musicTrackId != null) {
        final track = MusicLibrary.findById(project.musicTrackId!);
        if (track != null) {
          final candidate = p.join(tmp, '${track.id}_$ts.mp3');
          try {
            // ignore: avoid_print
            print('[MediaEncoder] loading music: ${track.assetPath}');
            final data = await rootBundle.load(track.assetPath);
            await File(candidate).writeAsBytes(data.buffer.asUint8List());
            extractedAudioPath = candidate;
            audioPath = candidate;
            // ignore: avoid_print
            print('[MediaEncoder] music ready: $candidate (${data.lengthInBytes} bytes)');
          } catch (e) {
            // ignore: avoid_print
            print('[MediaEncoder] music load failed: ${track.assetPath} — $e');
          }
        } else {
          // ignore: avoid_print
          print('[MediaEncoder] music track not found: ${project.musicTrackId}');
        }
      }

      // 6b. Per-frame voice-overs
      final frameVoiceovers = <String?>[];
      for (int i = 0; i < resolvedPaths.length; i++) {
        final vp = i < project.frameVoiceovers.length ? project.frameVoiceovers[i] : null;
        if (vp != null && File(vp).existsSync()) {
          frameVoiceovers.add(vp);
        } else {
          frameVoiceovers.add(null);
        }
      }

      // 7. Build + execute FFmpeg command
      final preComposedFlags = List.generate(
          resolvedPaths.length, (i) => preComposedPaths[i] != null);

      final command = MotionStyleEngine.build(
        inputPaths:        finalInputPaths,
        isVideo:           isVideoFlags,
        outputPath:        outputPath,
        textOverlays:      textOverlays,
        brandingPath:      brandingPath,
        audioPath:         audioPath,
        frameVoiceovers:   frameVoiceovers,
        totalDuration:     totalDuration,
        styleId:           project.motionStyleId,
        frameDurations:    resolvedDurations,
        preComposedFlags:  preComposedFlags,
        watermarkPath:     watermarkPngPath,
        countdownPath:     countdownPngPath,
        qrOverlayPath:     qrPngPath,
        outW:              outW,
        outH:              outH,
      );

      final result = await _runFFmpeg(
          command, outputPath, tmp, totalDuration, onProgress,
          projectJson: project.toJson());

      if (result.success) onProgress?.call(1.0);
      return result;
    } catch (e) {
      // ignore: avoid_print
      print('[MediaEncoder] exception: $e');
      return ExportResult.failure(e.toString());
    } finally {
      for (final path in [
        ...renderedTextPngs,
        ...compositeImagePaths,
        brandingPngPath,
        if (extractedAudioPath != null) extractedAudioPath,
        if (watermarkPngPath != null) watermarkPngPath,
        if (countdownPngPath != null) countdownPngPath,
        if (qrPngPath != null) qrPngPath,
      ]) {
        try { File(path).deleteSync(); } catch (_) {}
      }
    }
  }
}
