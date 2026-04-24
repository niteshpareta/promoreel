import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/router/safe_pop.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/tokens.dart';

/// Full-screen crop editor. Takes the current clip's source aspect and
/// a thumbnail to draw under the crop rectangle; returns the new
/// normalised rect `[x, y, w, h]` on Save. Cancel returns null.
///
/// UX:
/// - 4 corner handles resize the rect (anchor stays on the opposite corner).
/// - Interior drag moves the rect within the frame.
/// - Preset pills pick an aspect ratio and recenter.
/// - Reset clears crop to full frame.
class VideoCropScreen extends StatefulWidget {
  const VideoCropScreen({
    super.key,
    required this.sourceAspect,
    required this.initialRect,
    this.thumb,
  });

  final double sourceAspect;
  final List<double> initialRect;
  final Uint8List? thumb;

  @override
  State<VideoCropScreen> createState() => _VideoCropScreenState();
}

enum _CropPreset { free, square, portrait45, vertical916, landscape169 }

class _VideoCropScreenState extends State<VideoCropScreen> {
  // Rect in *source* frame coordinates, [0, 1].
  late double _x, _y, _w, _h;
  _CropPreset _preset = _CropPreset.free;

  @override
  void initState() {
    super.initState();
    _x = widget.initialRect[0].clamp(0.0, 1.0);
    _y = widget.initialRect[1].clamp(0.0, 1.0);
    _w = widget.initialRect[2].clamp(0.05, 1.0);
    _h = widget.initialRect[3].clamp(0.05, 1.0);
  }

  double? _aspectFor(_CropPreset p) => switch (p) {
        _CropPreset.free => null,
        _CropPreset.square => 1.0,
        _CropPreset.portrait45 => 4 / 5,
        _CropPreset.vertical916 => 9 / 16,
        _CropPreset.landscape169 => 16 / 9,
      };

  void _applyPreset(_CropPreset p) {
    PrHaptics.tap();
    setState(() => _preset = p);
    final aspect = _aspectFor(p);
    if (aspect == null) return;

    // Convert the target display aspect into SOURCE fractions —
    // aspect is in display (width/height). The source frame has its
    // own aspect `sourceAspect`. A centered rect that fills as much as
    // possible while matching the target aspect:
    final srcAsp = widget.sourceAspect;
    double w, h;
    if (aspect > srcAsp) {
      // target is wider → full width, shorter height
      w = 1.0;
      h = srcAsp / aspect;
    } else {
      // target is narrower → full height, slimmer width
      h = 1.0;
      w = aspect / srcAsp;
    }
    setState(() {
      _w = w;
      _h = h;
      _x = (1.0 - w) / 2;
      _y = (1.0 - h) / 2;
    });
  }

  void _reset() {
    PrHaptics.tap();
    setState(() {
      _x = 0;
      _y = 0;
      _w = 1;
      _h = 1;
      _preset = _CropPreset.free;
    });
  }

  void _save() {
    PrHaptics.commit();
    Navigator.of(context).pop<List<double>>([_x, _y, _w, _h]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _editor()),
            _presetRow(),
            const SizedBox(height: PrSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: PrButton(
                      label: 'Cancel',
                      variant: PrButtonVariant.secondary,
                      onPressed: () => safePop(context),
                    ),
                  ),
                  const SizedBox(width: PrSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: PrButton(
                      label: 'Save',
                      icon: PrIcons.check,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final isCropped =
        _x > 0.0001 || _y > 0.0001 || _w < 0.9999 || _h < 0.9999;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.xs, PrSpacing.xs, PrSpacing.sm, PrSpacing.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(PrIcons.back),
            onPressed: () => safePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CROP', style: AppTextStyles.kicker),
                Text('Adjust frame',
                    style: AppTextStyles.titleLarge, maxLines: 1),
              ],
            ),
          ),
          if (isCropped)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: AppTextStyles.labelSmall
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editor() {
    return Padding(
      padding: const EdgeInsets.all(PrSpacing.lg),
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.sourceAspect == 0 ? 9 / 16 : widget.sourceAspect,
          child: LayoutBuilder(builder: (ctx, box) {
            final W = box.maxWidth;
            final H = box.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Source preview (thumbnail). Uses a placeholder if no
                // thumb is available — rectangle geometry is still
                // accurate because AspectRatio drives the dimensions.
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.thumb != null
                        ? Image.memory(widget.thumb!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.bgSurfaceVariant,
                            alignment: Alignment.center,
                            child: const Icon(Icons.videocam_rounded,
                                color: AppColors.textDisabled, size: 40),
                          ),
                  ),
                ),
                // Dim everything outside the crop rect so the selection
                // reads strongly.
                _dimMask(W, H),
                // Crop rect + handles.
                _cropOverlay(W, H),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _dimMask(double W, double H) {
    final left = _x * W;
    final top = _y * H;
    final right = (1 - (_x + _w)) * W;
    final bottom = (1 - (_y + _h)) * H;
    Widget d(EdgeInsets p) => Positioned(
          left: p.left,
          top: p.top,
          right: p.right,
          bottom: p.bottom,
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        );
    return Stack(
      children: [
        d(EdgeInsets.only(right: W - left)),
        d(EdgeInsets.only(left: W - right)),
        d(EdgeInsets.only(left: left, right: right, bottom: H - top)),
        d(EdgeInsets.only(left: left, right: right, top: H - bottom)),
      ],
    );
  }

  Widget _cropOverlay(double W, double H) {
    final left = _x * W;
    final top = _y * H;
    final width = _w * W;
    final height = _h * H;
    const handleSize = 22.0;

    void resizeFromCorner(int corner, Offset delta) {
      // corner: 0 = TL, 1 = TR, 2 = BL, 3 = BR.
      final aspect = _aspectFor(_preset);
      final dxFrac = delta.dx / W;
      final dyFrac = delta.dy / H;

      double nx = _x, ny = _y, nw = _w, nh = _h;
      if (corner == 0 || corner == 2) {
        nx = (_x + dxFrac).clamp(0.0, _x + _w - 0.05);
        nw = _w - (nx - _x);
      } else {
        nw = (_w + dxFrac).clamp(0.05, 1.0 - _x);
      }
      if (corner == 0 || corner == 1) {
        ny = (_y + dyFrac).clamp(0.0, _y + _h - 0.05);
        nh = _h - (ny - _y);
      } else {
        nh = (_h + dyFrac).clamp(0.05, 1.0 - _y);
      }

      if (aspect != null) {
        // Preserve the locked aspect. Scale height off width using the
        // SOURCE aspect: display aspect = w*sourceAsp / h → h = w*sourceAsp/aspect.
        final srcAsp = widget.sourceAspect;
        final target = nw * srcAsp / aspect;
        if (target > 1.0) {
          nh = 1.0;
          nw = aspect / srcAsp;
        } else {
          nh = target.clamp(0.05, 1.0);
        }
        // Recompute y so the opposite corner stays anchored.
        if (corner == 0 || corner == 1) {
          ny = (_y + _h - nh).clamp(0.0, 1.0);
        }
        if (corner == 0 || corner == 2) {
          nx = (_x + _w - nw).clamp(0.0, 1.0);
        }
      }

      setState(() {
        _x = nx;
        _y = ny;
        _w = nw;
        _h = nh;
      });
    }

    void moveInterior(Offset delta) {
      final dxFrac = delta.dx / W;
      final dyFrac = delta.dy / H;
      setState(() {
        _x = (_x + dxFrac).clamp(0.0, 1.0 - _w);
        _y = (_y + dyFrac).clamp(0.0, 1.0 - _h);
      });
    }

    Widget handle(int corner, Alignment align) {
      return Positioned(
        left: switch (corner) {
          0 || 2 => -handleSize / 2,
          _ => width - handleSize / 2,
        },
        top: switch (corner) {
          0 || 1 => -handleSize / 2,
          _ => height - handleSize / 2,
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => resizeFromCorner(corner, d.delta),
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: AppColors.brandEmber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Interior drag area + ember border + rule-of-thirds grid.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => moveInterior(d.delta),
              child: CustomPaint(
                painter: _CropBorderPainter(),
              ),
            ),
          ),
          handle(0, Alignment.topLeft),
          handle(1, Alignment.topRight),
          handle(2, Alignment.bottomLeft),
          handle(3, Alignment.bottomRight),
        ],
      ),
    );
  }

  Widget _presetRow() {
    Widget pill(_CropPreset p, String label) {
      final active = _preset == p;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _applyPreset(p),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brandEmber.withValues(alpha: 0.2)
                    : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      active ? AppColors.brandEmber : AppColors.divider,
                  width: active ? 1.2 : 0.8,
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? AppColors.brandEmber
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.lg, vertical: PrSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            pill(_CropPreset.free, 'Free'),
            pill(_CropPreset.square, '1 : 1'),
            pill(_CropPreset.portrait45, '4 : 5'),
            pill(_CropPreset.vertical916, '9 : 16'),
            pill(_CropPreset.landscape169, '16 : 9'),
          ],
        ),
      ),
    );
  }
}

class _CropBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = AppColors.brandEmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = Offset.zero & size;
    canvas.drawRect(r, border);
    // Rule-of-thirds grid.
    for (int i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropBorderPainter oldDelegate) => false;
}
