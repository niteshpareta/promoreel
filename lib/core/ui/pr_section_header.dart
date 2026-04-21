import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'tokens.dart';

/// Section header with an optional "kicker" — the tracked all-caps
/// micro-label above the title that gives every page an editorial rhythm.
///
///     EDITOR'S PICKS  ← kicker (tiny, ember)
///     Recent reels    ← title (Manrope bold)
///     Your last 12 exports across all projects  ← subtitle (optional)
///
/// Use this everywhere there's a list or group header. Keep screens
/// consistent in voice.
class PrSectionHeader extends StatelessWidget {
  const PrSectionHeader({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null) ...[
                Text(kicker!.toUpperCase(), style: AppTextStyles.kicker),
                const SizedBox(height: PrSpacing.xxs + 2),
              ],
              Text(title, style: AppTextStyles.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
