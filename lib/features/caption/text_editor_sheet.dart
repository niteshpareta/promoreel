import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/tokens.dart';

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
    ),
  );
}

class _TextEditorSheet extends StatefulWidget {
  const _TextEditorSheet({
    required this.kind,
    required this.initialText,
    required this.frameIndex,
    required this.totalFrames,
  });

  final PrTextEditorKind kind;
  final String initialText;
  final int frameIndex;
  final int totalFrames;

  @override
  State<_TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _applyToAll = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
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
                onSubmitted: (_) => _apply(context),
              ),
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

  void _apply(BuildContext context) {
    PrHaptics.commit();
    Navigator.of(context).pop(
      PrTextEditorResult(_ctrl.text.trim(), _applyToAll),
    );
  }
}
