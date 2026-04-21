import 'package:flutter/widgets.dart';

/// Canonical representation for where a caption sits on a frame.
///
/// Serialised into `VideoProject.frameTextPositions` as a string so the
/// existing `List<String>` model + JSON stays unchanged. Accepted formats:
///
///   • `'top'`, `'center'`, `'bottom'` — legacy presets (still supported and
///     rendered identically to before).
///   • `'custom:X,Y'` — fractional coordinates of the caption *block centre*,
///     where X and Y are floats in `0.0..1.0` relative to the frame's width
///     and height. Example: `'custom:0.5,0.92'` ≈ bottom-centre.
///
/// Use [TextPositionX] helpers below to convert between presets and offsets.
class TextPosition {
  TextPosition._(this.raw, this.offset);

  /// The serialised form (e.g. `'bottom'`, `'custom:0.5,0.8'`).
  final String raw;

  /// Normalised `Offset` in `0..1` space. Always present — presets map to
  /// fixed offsets (see [_presetOffset]).
  final Offset offset;

  /// Whether the user has dragged to a custom position (vs. a legacy preset).
  bool get isCustom => raw.startsWith('custom:');

  /// Parse a raw string from [VideoProject.frameTextPositions]. Falls back to
  /// `'bottom'` for anything unknown so legacy projects stay compatible.
  factory TextPosition.parse(String raw) {
    if (raw.startsWith('custom:')) {
      final body = raw.substring('custom:'.length);
      final parts = body.split(',');
      if (parts.length == 2) {
        final x = double.tryParse(parts[0]);
        final y = double.tryParse(parts[1]);
        if (x != null && y != null) {
          return TextPosition._(raw, Offset(x.clamp(0, 1), y.clamp(0, 1)));
        }
      }
      // Malformed custom — fall back to bottom preset.
      return TextPosition._('bottom', _presetOffset('bottom'));
    }
    return TextPosition._(raw, _presetOffset(raw));
  }

  /// Build from a continuous drag offset (usually the caption block centre).
  factory TextPosition.fromOffset(Offset o) {
    final x = o.dx.clamp(0.0, 1.0);
    final y = o.dy.clamp(0.0, 1.0);
    final raw = 'custom:${x.toStringAsFixed(3)},${y.toStringAsFixed(3)}';
    return TextPosition._(raw, Offset(x, y));
  }

  /// Round-trip a drag offset through [TextPosition.fromOffset], snapping to
  /// the nearest preset if it's *very* close to one (keeps the data model
  /// readable — a `'bottom'` string is clearer than `'custom:0.500,0.920'`).
  factory TextPosition.fromOffsetWithPresetSnap(Offset o) {
    const snapDistance = 0.035; // ~3.5% of frame
    for (final preset in const ['top', 'center', 'bottom']) {
      final presetOffset = _presetOffset(preset);
      if ((o - presetOffset).distance < snapDistance) {
        return TextPosition._(preset, presetOffset);
      }
    }
    return TextPosition.fromOffset(o);
  }

  static Offset _presetOffset(String raw) {
    switch (raw) {
      case 'top':
        return const Offset(0.5, 0.12);
      case 'center':
        return const Offset(0.5, 0.50);
      case 'bottom':
      default:
        return const Offset(0.5, 0.90);
    }
  }
}

/// Snap guide result — used by the drag UI to show an alignment line and
/// gently pull the drag position to a canonical axis.
class TextSnapGuide {
  const TextSnapGuide({this.snappedX, this.snappedY});

  /// Normalised X the drag has snapped to (e.g. 0.5 for centre), or null.
  final double? snappedX;

  /// Normalised Y the drag has snapped to (rule-of-thirds lines), or null.
  final double? snappedY;

  bool get hasSnap => snappedX != null || snappedY != null;
}

/// While dragging, apply snap behaviour: when the pointer is within
/// [threshold] of a snap axis, lock to that axis and signal back to the UI.
TextSnapGuide applyDragSnap(Offset raw, {double threshold = 0.025}) {
  const xAxes = [0.5]; // horizontal centre only
  const yAxes = [0.12, 0.33, 0.5, 0.67, 0.90]; // top / third / centre / third / bottom

  double? snappedX;
  for (final a in xAxes) {
    if ((raw.dx - a).abs() < threshold) {
      snappedX = a;
      break;
    }
  }

  double? snappedY;
  for (final a in yAxes) {
    if ((raw.dy - a).abs() < threshold) {
      snappedY = a;
      break;
    }
  }

  return TextSnapGuide(snappedX: snappedX, snappedY: snappedY);
}

/// Apply the snap guide back onto an Offset — returns a new Offset with
/// any locked axes replaced by the snap value.
Offset snapOffset(Offset raw, TextSnapGuide guide) {
  return Offset(
    guide.snappedX ?? raw.dx,
    guide.snappedY ?? raw.dy,
  );
}
