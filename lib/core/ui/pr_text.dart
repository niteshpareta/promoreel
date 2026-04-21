import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Devanagari-aware text. If the string contains any Devanagari codepoint
/// (U+0900–U+097F), falls back to a Noto Sans Devanagari style that has the
/// glyphs; otherwise renders the supplied Latin style.
///
/// Use this for any text that *might* contain Hindi at runtime — product
/// names, business names, user-entered captions. Don't use for purely
/// English labels baked into the UI (it adds a codepoint check per frame).
class PrText extends StatelessWidget {
  const PrText(
    this.text, {
    super.key,
    this.style,
    this.hindiStyle,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;

  /// Override for Hindi fallback. Defaults to [AppTextStyles.bodyHindi].
  final TextStyle? hindiStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  static final _devanagari = RegExp(r'[ऀ-ॿ]');

  @override
  Widget build(BuildContext context) {
    final hasHindi = _devanagari.hasMatch(text);
    final resolved = hasHindi
        ? (hindiStyle ?? AppTextStyles.bodyHindi).merge(style)
        : (style ?? AppTextStyles.bodyMedium);
    return Text(
      text,
      style: resolved,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
