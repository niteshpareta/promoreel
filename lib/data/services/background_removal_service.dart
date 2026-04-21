import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device background removal powered by Google ML Kit Subject Segmentation.
///
/// Given an input image and a solid replacement colour, returns a PNG with
/// the subject(s) composited over that colour. The model downloads on first
/// use (~6 MB) and is cached by the OS thereafter — no network is required
/// on subsequent runs, preserving the app's offline-first promise.
///
/// Cutouts are cached on disk (keyed by input file hash + bg colour) so
/// repeated previews and re-renders don't re-run the segmenter, which
/// takes roughly 500–1500 ms per image depending on resolution and device.
class BackgroundRemovalService {
  BackgroundRemovalService._();

  static SubjectSegmenter? _segmenter;

  static SubjectSegmenter _get() {
    return _segmenter ??= SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundConfidenceMask: true,
        enableForegroundBitmap: true,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );
  }

  /// Free the model from memory. Call when leaving the editor for a while.
  static Future<void> dispose() async {
    await _segmenter?.close();
    _segmenter = null;
  }

  /// Segment the subject in [inputPath] and composite over [backgroundColorArgb].
  /// Returns the output PNG path, or `null` if segmentation failed (no subject
  /// detected, decode error, etc.) so callers can gracefully fall back to
  /// the original image.
  static Future<String?> processToPath({
    required String inputPath,
    required int backgroundColorArgb,
  }) async {
    if (!File(inputPath).existsSync()) return null;

    final cachePath = await _cachePath(inputPath, backgroundColorArgb);
    if (File(cachePath).existsSync()) return cachePath;

    try {
      final result = await _get().processImage(
        InputImage.fromFilePath(inputPath),
      );
      final fgBitmap = result.foregroundBitmap;
      if (fgBitmap == null) return null;

      // Width/height come from the decoded PNG header of the bitmap ML Kit
      // hands back. We read them via dart:ui since the package doesn't
      // expose them directly.
      final fgImage = await _decode(fgBitmap);
      final composedBytes = await _compositeOntoColor(
        fg: fgImage,
        backgroundColorArgb: backgroundColorArgb,
      );
      fgImage.dispose();

      await File(cachePath).writeAsBytes(composedBytes);
      return cachePath;
    } catch (e, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[BackgroundRemoval] failed: $e\n$stack');
      }
      return null;
    }
  }

  // ── Composite ───────────────────────────────────────────────────────────

  static Future<ui.Image> _decode(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  static Future<Uint8List> _compositeOntoColor({
    required ui.Image fg,
    required int backgroundColorArgb,
  }) async {
    final width = fg.width;
    final height = fg.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Flat background fill.
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = ui.Color(backgroundColorArgb),
    );
    // Subject on top (its own alpha handles the mask).
    canvas.drawImage(fg, ui.Offset.zero, ui.Paint());

    final picture = recorder.endRecording();
    final composed = await picture.toImage(width, height);
    final byteData =
        await composed.toByteData(format: ui.ImageByteFormat.png);
    composed.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode subject-segmented PNG');
    }
    return byteData.buffer.asUint8List();
  }

  // ── Cache ───────────────────────────────────────────────────────────────

  static Future<String> _cachePath(
    String inputPath,
    int backgroundColorArgb,
  ) async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(dir.path, 'promorreel_bg_cache'));
    if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

    final stat = File(inputPath).statSync();
    final keySource =
        '$inputPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}|$backgroundColorArgb';
    return p.join(cacheDir.path, '${_stableHash(keySource)}.png');
  }

  /// Deterministic non-cryptographic hash — enough to key a disk cache.
  /// Avoids pulling the `crypto` package just for an md5 filename.
  static String _stableHash(String input) {
    var hash = 0x811C9DC5; // FNV-1a 32-bit offset basis
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
