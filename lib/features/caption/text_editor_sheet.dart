import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/tokens.dart';
import '../../data/models/badge_style.dart';
import '../../data/models/caption_style.dart';
import '../../engine/badge_painter.dart';
import '../../engine/text_renderer.dart' show googleFontsStyleFor;

/// Which text role we're editing — affects the keyboard type, prefix, and
/// the "Apply to all" label.
enum PrTextEditorKind {
  caption,
  price,
  mrp,
}

/// Modal bottom sheet for editing a single text field on a frame.
///
/// Opened from a tap on the preview. Returns:
///   • `null` → user cancelled / swiped down
///   • `(text, applyToAll: bool)` → user saved
class PrTextEditorResult {
  const PrTextEditorResult(this.text, this.applyToAll);
  final String text;
  final bool applyToAll;
}

Future<PrTextEditorResult?> showPrTextEditor(
  BuildContext context, {
  required PrTextEditorKind kind,
  required String initialText,
  required int frameIndex,
  required int totalFrames,
  String initialCaptionStyleId = CaptionStyle.defaultStyleId,

  /// Invoked when the user picks a caption style from the Style sub-sheet.
  /// The callback writes straight through to the provider so the style
  /// sticks even if the user dismisses without pressing Apply on the text.
  /// Only used when [kind] is [PrTextEditorKind.caption].
  ValueChanged<String>? onCaptionStyleChanged,
}) {
  return showModalBottomSheet<PrTextEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _TextEditorSheet(
      kind: kind,
      initialText: initialText,
      frameIndex: frameIndex,
      totalFrames: totalFrames,
      initialCaptionStyleId: initialCaptionStyleId,
      onCaptionStyleChanged: onCaptionStyleChanged,
    ),
  );
}

class _TextEditorSheet extends StatefulWidget {
  const _TextEditorSheet({
    required this.kind,
    required this.initialText,
    required this.frameIndex,
    required this.totalFrames,
    required this.initialCaptionStyleId,
    required this.onCaptionStyleChanged,
  });

  final PrTextEditorKind kind;
  final String initialText;
  final int frameIndex;
  final int totalFrames;
  final String initialCaptionStyleId;
  final ValueChanged<String>? onCaptionStyleChanged;

  @override
  State<_TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _applyToAll = false;

  /// Currently-selected caption style id. Kept locally so the mini-preview
  /// updates instantly without a provider round-trip; also forwarded to the
  /// parent via `widget.onCaptionStyleChanged` on every pick.
  late String _captionStyleId;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
    _captionStyleId = widget.initialCaptionStyleId;
    // Autofocus on next frame so the keyboard rises with the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  (String, String, IconData, TextInputType, int, String) _config() {
    switch (widget.kind) {
      case PrTextEditorKind.caption:
        return (
          'Caption',
          'Short line — headline over the photo',
          PrIcons.text,
          TextInputType.text,
          60,
          'Use on all frames',
        );
      case PrTextEditorKind.price:
        return (
          'Price',
          'Selling price — shown in the corner badge',
          PrIcons.price,
          const TextInputType.numberWithOptions(decimal: true),
          10,
          'Use on all frames',
        );
      case PrTextEditorKind.mrp:
        return (
          'MRP',
          'Strike-through original price',
          Icons.price_change_rounded,
          const TextInputType.numberWithOptions(decimal: true),
          10,
          'Use on all frames',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;

    final (title, subtitle, icon, keyboard, maxLen, applyLabel) = _config();
    final canApplyToAll = widget.totalFrames > 1;

    return Padding(
      // Push sheet above the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PrRadius.xl),
          ),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(PrRadius.sm),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 18),
                  ),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.headlineMedium),
                        Text(
                          'Frame ${widget.frameIndex + 1} of ${widget.totalFrames} · $subtitle',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.xs, PrSpacing.lg, PrSpacing.xs),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                keyboardType: keyboard,
                textCapitalization: widget.kind == PrTextEditorKind.caption
                    ? TextCapitalization.sentences
                    : TextCapitalization.none,
                maxLength: maxLen,
                maxLines: widget.kind == PrTextEditorKind.caption ? 2 : 1,
                minLines: 1,
                style: AppTextStyles.headlineSmall,
                inputFormatters: widget.kind == PrTextEditorKind.caption
                    ? null
                    : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  hintText: widget.kind == PrTextEditorKind.caption
                      ? 'e.g. New arrivals · 20% off today'
                      : '₹ amount',
                  prefixIcon: widget.kind == PrTextEditorKind.caption
                      ? null
                      : const Padding(
                          padding: EdgeInsets.only(left: 14, right: 8),
                          child: Text('₹',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  counterStyle: AppTextStyles.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                onChanged: (_) {
                  if (widget.kind == PrTextEditorKind.caption) {
                    setState(() {});
                  }
                },
                onSubmitted: (_) => _apply(context),
              ),
            ),
            if (widget.kind == PrTextEditorKind.caption)
              _StyleToolbar(
                previewText: _ctrl.text.trim().isEmpty
                    ? 'Preview'
                    : _ctrl.text.trim(),
                captionStyle: CaptionStyle.byId(_captionStyleId),
                onPickStyle: _openStyleSheet,
              ),
            if (canApplyToAll)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Checkbox(
                      value: _applyToAll,
                      onChanged: (v) =>
                          setState(() => _applyToAll = v ?? false),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: scheme.onSurfaceVariant),
                    ),
                    Text(applyLabel,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: scheme.onSurface,
                        )),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  PrSpacing.lg,
                  PrSpacing.sm,
                  PrSpacing.lg,
                  PrSpacing.md + media.padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: PrButton(
                      label: 'Clear',
                      variant: PrButtonVariant.secondary,
                      size: PrButtonSize.md,
                      onPressed: () {
                        PrHaptics.tap();
                        _ctrl.clear();
                        _focus.requestFocus();
                      },
                    ),
                  ),
                  const SizedBox(width: PrSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: PrButton(
                      label: 'Apply',
                      icon: PrIcons.check,
                      size: PrButtonSize.md,
                      onPressed: () => _apply(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStyleSheet() async {
    PrHaptics.tap();
    final picked = await showCaptionStyleSheet(
      context,
      initialStyleId: _captionStyleId,
      sampleText: _ctrl.text.trim().isEmpty ? 'Aa' : _ctrl.text.trim(),
    );
    if (picked == null || !mounted) return;
    setState(() => _captionStyleId = picked);
    widget.onCaptionStyleChanged?.call(picked);
  }

  void _apply(BuildContext context) {
    PrHaptics.commit();
    Navigator.of(context).pop(
      PrTextEditorResult(_ctrl.text.trim(), _applyToAll),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Style toolbar strip — sits under the text field. Shows the live styled
// caption on the left and the [✨ Style] launcher icon on the right. More
// axes (Font / Color / Effect / Motion) will plug in here as their own
// icons later; keeping this row lean is the whole point of the
// per-option-sheet pattern.
// ─────────────────────────────────────────────────────────────────────────────

class _StyleToolbar extends StatelessWidget {
  const _StyleToolbar({
    required this.previewText,
    required this.captionStyle,
    required this.onPickStyle,
  });

  final String previewText;
  final CaptionStyle captionStyle;
  final VoidCallback onPickStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.lg, PrSpacing.sm, PrSpacing.lg, 0),
      child: Row(
        children: [
          Expanded(
            child: _StylePreviewChip(
              previewText: previewText,
              captionStyle: captionStyle,
            ),
          ),
          const SizedBox(width: PrSpacing.sm),
          _ToolbarIconButton(
            icon: Icons.auto_awesome_rounded,
            label: 'Style',
            active: true,
            tint: scheme.primary,
            onTap: onPickStyle,
          ),
        ],
      ),
    );
  }
}

class _StylePreviewChip extends StatelessWidget {
  const _StylePreviewChip({
    required this.previewText,
    required this.captionStyle,
  });

  final String previewText;
  final CaptionStyle captionStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    const double fontPx = 16;
    final double padH = fontPx * 0.7;
    final double padV = fontPx * 0.3;
    final double radius = fontPx * 0.7;

    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Subtle checker-like tinted backdrop so the pill and glow presets
        // read against something more photo-like than pure bg.
        color: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(PrRadius.md),
      ),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: captionStyle.pillColor != null
              ? BoxDecoration(
                  color: captionStyle.pillColor,
                  borderRadius: BorderRadius.circular(radius),
                )
              : null,
          child: Text(
            previewText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: googleFontsStyleFor(captionStyle, fontSize: fontPx),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: PrSpacing.sm, vertical: PrSpacing.xs),
          decoration: BoxDecoration(
            color: active ? tint.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: active ? tint : AppColors.divider,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption style bottom sheet — the "Style" axis. Usable both stacked on top
// of the text editor and standalone from the frame card. Tapping a tile
// pops the sheet with its id; the caller writes that back through the
// provider.
// ─────────────────────────────────────────────────────────────────────────────

/// Open the Caption Style picker. Returns the chosen style id, or null if
/// the user dismissed the sheet without picking.
Future<String?> showCaptionStyleSheet(
  BuildContext context, {
  required String initialStyleId,
  required String sampleText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _CaptionStyleSheet(
      initialStyleId: initialStyleId,
      sampleText: sampleText,
    ),
  );
}

class _CaptionStyleSheet extends StatelessWidget {
  const _CaptionStyleSheet({
    required this.initialStyleId,
    required this.sampleText,
  });

  final String initialStyleId;
  final String sampleText;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PrRadius.xl),
          ),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(PrRadius.sm),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: scheme.primary, size: 18),
                  ),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Caption style',
                            style: AppTextStyles.headlineMedium),
                        Text(
                          'Tap a look — fonts, colour, and pill are all handled.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.md),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: CaptionStyle.all.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: PrSpacing.sm,
                  mainAxisSpacing: PrSpacing.sm,
                ),
                itemBuilder: (ctx, i) {
                  final style = CaptionStyle.all[i];
                  return _CaptionStyleTile(
                    style: style,
                    sampleText: sampleText,
                    selected: style.id == initialStyleId,
                    onTap: () {
                      PrHaptics.select();
                      Navigator.of(ctx).pop(style.id);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: media.padding.bottom + PrSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _CaptionStyleTile extends StatelessWidget {
  const _CaptionStyleTile({
    required this.style,
    required this.sampleText,
    required this.selected,
    required this.onTap,
  });

  final CaptionStyle style;
  final String sampleText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double fontPx = 18;
    final double padH = fontPx * 0.75;
    final double padV = fontPx * 0.35;
    final double radius = fontPx * 0.7;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: IntrinsicWidth(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: padH, vertical: padV),
                    decoration: style.pillColor != null
                        ? BoxDecoration(
                            color: style.pillColor,
                            borderRadius: BorderRadius.circular(radius),
                          )
                        : null,
                    child: Text(
                      // Cap the tile sample to 2 words for consistent sizing.
                      _truncateForTile(sampleText),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          googleFontsStyleFor(style, fontSize: fontPx),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(
                  style.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateForTile(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length <= 2) return s.trim();
    return '${parts.first} ${parts[1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption COLOR sub-sheet — two swatch rows (text colour / pill colour).
// Returns a record `({int? textColor, int? pillColor})`; either field may
// be null meaning "user didn't touch that row." The pill row is hidden
// when the preset has no pill (switching to a filled preset first is
// required in that case).
// ─────────────────────────────────────────────────────────────────────────────

/// Result of the color sub-sheet — fields are nullable so the caller knows
/// which axes actually changed.
class CaptionColorResult {
  const CaptionColorResult({this.textColor, this.pillColor});
  final int? textColor;
  final int? pillColor;
}

/// Text colour palette — curated set that reads well on photos.
const List<int> _textColorPalette = [
  0xFFFFFFFF, // white
  0xFF121212, // near-black
  0xFFF2A848, // brand ember
  0xFFE8B84D, // gold
  0xFF4DE1FF, // cyan
  0xFFFF6E40, // sale orange
  0xFF00C853, // new green
  0xFFFF3D00, // hot red
  0xFFF5E6D3, // ivory
];

/// Pill colour palette — solid, high-contrast backgrounds.
const List<int> _pillColorPalette = [
  0x8C000000, // translucent black (default clean)
  0xFF121212, // solid charcoal
  0xFFFFFFFF, // white
  0xFFF2A848, // ember
  0xFF7A1F14, // maroon
  0xFF0A2A6B, // deep blue
  0xFF1B5E20, // deep green
  0xFFAD1457, // wine
  0xFF5E35B1, // purple
];

Future<CaptionColorResult?> showCaptionColorSheet(
  BuildContext context, {
  required CaptionStyle currentStyle,
  required bool hasPill,
}) {
  return showModalBottomSheet<CaptionColorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) =>
        _CaptionColorSheet(currentStyle: currentStyle, hasPill: hasPill),
  );
}

class _CaptionColorSheet extends StatefulWidget {
  const _CaptionColorSheet({
    required this.currentStyle,
    required this.hasPill,
  });

  final CaptionStyle currentStyle;
  final bool hasPill;

  @override
  State<_CaptionColorSheet> createState() => _CaptionColorSheetState();
}

class _CaptionColorSheetState extends State<_CaptionColorSheet> {
  int? _textColor;
  int? _pillColor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;

    // Build a preview style that reflects the uncommitted picks.
    final previewStyle = widget.currentStyle.withOverrides(
      textColorOverride: _textColor,
      pillColorOverride: _pillColor,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: Icons.palette_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Caption colour',
                            style: AppTextStyles.headlineMedium),
                        Text('Pick text — and pill if the preset has one.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Live preview of the colour picks.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.sm),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(PrRadius.md),
                ),
                alignment: Alignment.center,
                child: _StylePreviewChip(
                  previewText: 'Aa',
                  captionStyle: previewStyle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.sm),
              child: Text('Text colour',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800)),
            ),
            _SwatchRow(
              palette: _textColorPalette,
              selected:
                  _textColor ?? widget.currentStyle.textColor.toARGB32(),
              onSelected: (c) => setState(() => _textColor = c),
            ),
            if (widget.hasPill) ...[
              const SizedBox(height: PrSpacing.md),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.sm),
                child: Text('Pill colour',
                    style: AppTextStyles.labelMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800)),
              ),
              _SwatchRow(
                palette: _pillColorPalette,
                selected: _pillColor ??
                    (widget.currentStyle.pillColor?.toARGB32() ?? 0),
                onSelected: (c) => setState(() => _pillColor = c),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(
                  PrSpacing.lg,
                  PrSpacing.md,
                  PrSpacing.lg,
                  PrSpacing.md + media.padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: PrButton(
                      label: 'Cancel',
                      variant: PrButtonVariant.secondary,
                      size: PrButtonSize.md,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: PrSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: PrButton(
                      label: 'Apply',
                      icon: PrIcons.check,
                      size: PrButtonSize.md,
                      onPressed: () {
                        PrHaptics.commit();
                        Navigator.of(context).pop(CaptionColorResult(
                          textColor: _textColor,
                          pillColor: _pillColor,
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeaderIcon extends StatelessWidget {
  const _SheetHeaderIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(PrRadius.sm),
      ),
      child: Icon(icon, color: scheme.primary, size: 18),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.palette,
    required this.selected,
    required this.onSelected,
  });

  final List<int> palette;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PrSpacing.lg),
        itemCount: palette.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final c = palette[i];
          final isSelected = selected == c;
          return GestureDetector(
            onTap: () {
              PrHaptics.select();
              onSelected(c);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brandEmber : AppColors.divider,
                  width: isSelected ? 2.4 : 1,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption EFFECT sub-sheet — 4 chips (Shadow / Outline / Glow / None).
// Pops with the picked effect id, or null if dismissed.
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> showCaptionEffectSheet(
  BuildContext context, {
  required CaptionStyle currentStyle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _CaptionEffectSheet(currentStyle: currentStyle),
  );
}

class _CaptionEffectSheet extends StatelessWidget {
  const _CaptionEffectSheet({required this.currentStyle});
  final CaptionStyle currentStyle;

  static const List<(CaptionEffect, String)> _options = [
    (CaptionEffect.shadow, 'Shadow'),
    (CaptionEffect.outline, 'Outline'),
    (CaptionEffect.glow, 'Glow'),
    (CaptionEffect.none, 'None'),
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;
    final currentId = effectId(currentStyle.effect);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: hairline, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: Icons.blur_on_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Text effect',
                            style: AppTextStyles.headlineMedium),
                        Text('How the caption lifts off the photo.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.md),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _options.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: PrSpacing.sm,
                  mainAxisSpacing: PrSpacing.sm,
                ),
                itemBuilder: (ctx, i) {
                  final opt = _options[i];
                  final styleWithEffect =
                      currentStyle.withOverrides(effectOverride: opt.$1);
                  return _CaptionEffectTile(
                    label: opt.$2,
                    style: styleWithEffect,
                    selected: effectId(opt.$1) == currentId,
                    onTap: () {
                      PrHaptics.select();
                      Navigator.of(ctx).pop(effectId(opt.$1));
                    },
                  );
                },
              ),
            ),
            SizedBox(height: media.padding.bottom + PrSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _CaptionEffectTile extends StatelessWidget {
  const _CaptionEffectTile({
    required this.label,
    required this.style,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final CaptionStyle style;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double fontPx = 22;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  'Aa',
                  style: googleFontsStyleFor(style, fontSize: fontPx),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: scheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption FONT sub-sheet — horizontal scroll of typeface tiles. Pops with
// the picked Google-Fonts family name, or null if dismissed.
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> showCaptionFontSheet(
  BuildContext context, {
  required String currentFamily,
  required String sampleText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _CaptionFontSheet(
      currentFamily: currentFamily,
      sampleText: sampleText,
    ),
  );
}

class _CaptionFontSheet extends StatelessWidget {
  const _CaptionFontSheet({
    required this.currentFamily,
    required this.sampleText,
  });
  final String currentFamily;
  final String sampleText;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: hairline, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: Icons.text_fields_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Font', style: AppTextStyles.headlineMedium),
                        Text('Typefaces curated for captions.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.md),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kCaptionFontOptions.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: PrSpacing.sm,
                  mainAxisSpacing: PrSpacing.sm,
                ),
                itemBuilder: (ctx, i) {
                  final opt = kCaptionFontOptions[i];
                  final isSelected = opt.family == currentFamily;
                  return _CaptionFontTile(
                    option: opt,
                    sampleText: sampleText,
                    selected: isSelected,
                    onTap: () {
                      PrHaptics.select();
                      Navigator.of(ctx).pop(opt.family);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: media.padding.bottom + PrSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _CaptionFontTile extends StatelessWidget {
  const _CaptionFontTile({
    required this.option,
    required this.sampleText,
    required this.selected,
    required this.onTap,
  });

  final CaptionFontOption option;
  final String sampleText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  _truncate(sampleText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: googleFontsStyleFor(
                    CaptionStyle.defaultStyle.withOverrides(
                        fontFamilyOverride: option.family),
                    fontSize: 22,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(option.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: scheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncate(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'Aa';
    if (t.length > 10) return '${t.substring(0, 10)}…';
    return t;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption MOTION sub-sheet — entrance animation tiles + rotation slider.
// Returns both axes in one record; either may be null meaning "the user
// didn't change that axis during this visit."
// ─────────────────────────────────────────────────────────────────────────────

class CaptionMotionResult {
  const CaptionMotionResult({this.animStyle, this.rotation});
  final String? animStyle;
  final int? rotation;
}

Future<CaptionMotionResult?> showCaptionMotionSheet(
  BuildContext context, {
  required String currentAnimStyle,
  required int currentRotation,
}) {
  return showModalBottomSheet<CaptionMotionResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _CaptionMotionSheet(
      initialAnim: currentAnimStyle,
      initialRotation: currentRotation,
    ),
  );
}

class _CaptionMotionSheet extends StatefulWidget {
  const _CaptionMotionSheet({
    required this.initialAnim,
    required this.initialRotation,
  });
  final String initialAnim;
  final int initialRotation;

  @override
  State<_CaptionMotionSheet> createState() => _CaptionMotionSheetState();
}

class _CaptionMotionSheetState extends State<_CaptionMotionSheet> {
  late String _anim;
  late int _rotation;

  static const List<(String, String, IconData)> _options = [
    ('none', 'None', Icons.block_rounded),
    ('fade', 'Fade', Icons.gradient_rounded),
    ('slide_up', 'Slide Up', Icons.arrow_upward_rounded),
    ('typewriter', 'Typewriter', Icons.keyboard_rounded),
    ('wipe', 'Wipe', Icons.swipe_right_alt_rounded),
    ('pop', 'Pop', Icons.auto_graph_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _anim = widget.initialAnim;
    _rotation = widget.initialRotation;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: Icons.animation_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Motion', style: AppTextStyles.headlineMedium),
                        Text(
                            'Entrance animation + tilt. Applies on export; '
                            'the tile preview shows the still pose.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.sm),
              child: Text('Entrance',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.md),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _options.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: PrSpacing.sm,
                  mainAxisSpacing: PrSpacing.sm,
                ),
                itemBuilder: (ctx, i) {
                  final opt = _options[i];
                  final selected = _anim == opt.$1;
                  return _MotionTile(
                    label: opt.$2,
                    icon: opt.$3,
                    selected: selected,
                    onTap: () {
                      PrHaptics.select();
                      setState(() => _anim = opt.$1);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  Text('Tilt',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${_rotation >= 0 ? '+' : ''}$_rotation°',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: PrSpacing.lg),
              child: Slider(
                value: _rotation.toDouble(),
                min: -15,
                max: 15,
                divisions: 30,
                onChanged: (v) => setState(() => _rotation = v.round()),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  PrSpacing.lg,
                  PrSpacing.sm,
                  PrSpacing.lg,
                  PrSpacing.md + media.padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: PrButton(
                      label: 'Cancel',
                      variant: PrButtonVariant.secondary,
                      size: PrButtonSize.md,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: PrSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: PrButton(
                      label: 'Apply',
                      icon: PrIcons.check,
                      size: PrButtonSize.md,
                      onPressed: () {
                        PrHaptics.commit();
                        Navigator.of(context).pop(CaptionMotionResult(
                          animStyle: _anim == widget.initialAnim ? null : _anim,
                          rotation:
                              _rotation == widget.initialRotation ? null : _rotation,
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionTile extends StatelessWidget {
  const _MotionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color:
                      selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE sheets — Style, Color (fill or text), Motion. Follow the same
// pattern as the caption equivalents so users don't have to re-learn a
// second interaction model.
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> showBadgeStyleSheet(
  BuildContext context, {
  required String initialStyleId,
  required String sampleText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _BadgeStyleSheet(
      initialStyleId: initialStyleId,
      sampleText: sampleText,
    ),
  );
}

class _BadgeStyleSheet extends StatelessWidget {
  const _BadgeStyleSheet({
    required this.initialStyleId,
    required this.sampleText,
  });
  final String initialStyleId;
  final String sampleText;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: hairline, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: Icons.local_offer_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Badge style',
                            style: AppTextStyles.headlineMedium),
                        Text('Shape + colours + decoration in one tap.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.md),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: BadgeStyle.all.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: PrSpacing.sm,
                  mainAxisSpacing: PrSpacing.sm,
                ),
                itemBuilder: (ctx, i) {
                  final s = BadgeStyle.all[i];
                  return _BadgeStyleTile(
                    style: s,
                    sampleText: sampleText,
                    selected: s.id == initialStyleId,
                    onTap: () {
                      PrHaptics.select();
                      Navigator.of(ctx).pop(s.id);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: media.padding.bottom + PrSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _BadgeStyleTile extends StatelessWidget {
  const _BadgeStyleTile({
    required this.style,
    required this.sampleText,
    required this.selected,
    required this.onTap,
  });
  final BadgeStyle style;
  final String sampleText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StyledBadge(
                    style: style,
                    text: _shortSample(sampleText),
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(style.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: scheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortSample(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'SALE';
    if (t.length > 8) return t.substring(0, 8);
    return t;
  }
}

enum BadgeColorAxis { fill, text }

Future<int?> showBadgeColorSheet(
  BuildContext context, {
  required BadgeStyle currentStyle,
  required BadgeColorAxis axis,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) =>
        _BadgeColorSheet(currentStyle: currentStyle, axis: axis),
  );
}

class _BadgeColorSheet extends StatelessWidget {
  const _BadgeColorSheet({
    required this.currentStyle,
    required this.axis,
  });
  final BadgeStyle currentStyle;
  final BadgeColorAxis axis;

  static const List<int> _palette = [
    0xFFFFFFFF, // white
    0xFF121212, // near-black
    0xFFF2A848, // ember
    0xFFE53935, // red
    0xFF00C853, // green
    0xFFFF6E40, // sale orange
    0xFF4DE1FF, // cyan
    0xFFD4A014, // gold
    0xFF7A1F14, // maroon
    0xFF5E35B1, // purple
    0xFFFFB300, // amber
    0xFF3D2307, // dark brown
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;
    final title = axis == BadgeColorAxis.fill ? 'Fill colour' : 'Text colour';
    final currentArgb = axis == BadgeColorAxis.fill
        ? currentStyle.fillColor.toARGB32()
        : currentStyle.textColor.toARGB32();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: axis == BadgeColorAxis.fill
                      ? Icons.format_color_fill_rounded
                      : Icons.format_color_text_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.headlineMedium),
                        Text(
                          'Overrides the preset — tap a swatch to apply.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: PrSpacing.lg),
                itemCount: _palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final c = _palette[i];
                  final isSel = currentArgb == c;
                  return GestureDetector(
                    onTap: () {
                      PrHaptics.select();
                      Navigator.of(ctx).pop(c);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? AppColors.brandEmber
                              : AppColors.divider,
                          width: isSel ? 2.6 : 1,
                        ),
                      ),
                      child: isSel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: media.padding.bottom + PrSpacing.md),
          ],
        ),
      ),
    );
  }
}

Future<String?> showBadgeAnimSheet(
  BuildContext context, {
  required String currentAnim,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) => _BadgeAnimSheet(currentAnim: currentAnim),
  );
}

class _BadgeAnimSheet extends StatelessWidget {
  const _BadgeAnimSheet({required this.currentAnim});
  final String currentAnim;

  static const List<(String, String, IconData)> _options = [
    ('none', 'None', Icons.block_rounded),
    ('pop', 'Pop In', Icons.auto_graph_rounded),
    ('slide_in', 'Slide In', Icons.swipe_right_alt_rounded),
    ('rotate_in', 'Rotate', Icons.rotate_right_rounded),
    ('pulse', 'Pulse', Icons.favorite_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final scheme = Theme.of(context).colorScheme;
    final selected = currentAnim.isEmpty ? 'none' : currentAnim;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrRadius.xl)),
          border: Border(top: BorderSide(color: hairline, width: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: PrSpacing.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: hairline, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.sm),
              child: Row(
                children: [
                  _SheetHeaderIcon(icon: Icons.animation_rounded),
                  const SizedBox(width: PrSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Badge motion',
                            style: AppTextStyles.headlineMedium),
                        Text('How the badge arrives on each slide.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.md),
              child: Wrap(
                spacing: PrSpacing.sm,
                runSpacing: PrSpacing.sm,
                children: _options.map((opt) {
                  final isSel = opt.$1 == selected;
                  return GestureDetector(
                    onTap: () {
                      PrHaptics.select();
                      Navigator.of(context).pop(opt.$1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? scheme.primary.withValues(alpha: 0.16)
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(PrRadius.md),
                        border: Border.all(
                          color:
                              isSel ? scheme.primary : AppColors.divider,
                          width: isSel ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(opt.$3,
                              size: 16,
                              color: isSel
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(opt.$2,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: isSel
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: media.padding.bottom + PrSpacing.sm),
          ],
        ),
      ),
    );
  }
}
