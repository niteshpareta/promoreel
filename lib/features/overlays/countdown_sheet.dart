import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/project_provider.dart';

void showCountdownSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _CountdownSheet(),
  );
}

class _CountdownSheet extends ConsumerStatefulWidget {
  const _CountdownSheet();

  @override
  ConsumerState<_CountdownSheet> createState() => _CountdownSheetState();
}

class _CountdownSheetState extends ConsumerState<_CountdownSheet> {
  late TextEditingController _ctrl;

  static const _presets = [
    'Offer ends today!',
    'Limited time only!',
    'Only 2 hours left!',
    'Today\'s special offer',
    'Hurry — stock limited!',
    'Flash Sale — Now!',
  ];

  @override
  void initState() {
    super.initState();
    final p = ref.read(projectProvider);
    _ctrl = TextEditingController(text: p?.countdownText ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final notifier = ref.read(projectProvider.notifier);
    final text = _ctrl.text.trim();
    notifier.setCountdownText(text.isEmpty ? null : text);
    notifier.setCountdownEnabled(text.isNotEmpty);
    Navigator.pop(context);
  }

  void _remove() {
    final notifier = ref.read(projectProvider.notifier);
    notifier.setCountdownText(null);
    notifier.setCountdownEnabled(false);
    _ctrl.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasText = _ctrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_rounded,
                    color: Color(0xFFE53935), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Urgency Banner',
                        style: AppTextStyles.titleMedium),
                    Text('Shown at the top of every frame',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Live preview
          if (hasText)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFFF6D00)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⏰  ',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                  Flexible(
                    child: Text(
                      _ctrl.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              controller: _ctrl,
              onChanged: (_) => setState(() {}),
              maxLength: 40,
              style: AppTextStyles.bodySmall
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'e.g. Offer ends today!',
                hintStyle: TextStyle(
                    color: AppColors.textDisabled, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                counterStyle: TextStyle(
                    color: AppColors.textDisabled, fontSize: 9),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Preset chips
          Text('Quick picks',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((preset) {
              final sel = _ctrl.text.trim() == preset;
              return GestureDetector(
                onTap: () {
                  _ctrl.text = preset;
                  _ctrl.selection = TextSelection.collapsed(
                      offset: preset.length);
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFE53935).withValues(alpha: 0.15)
                        : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFFE53935)
                          : AppColors.divider,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(preset,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: sel
                            ? const Color(0xFFE53935)
                            : AppColors.textSecondary,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      )),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              if (ref.read(projectProvider)?.countdownEnabled == true) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _remove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Remove'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: hasText ? _apply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Urgency Banner'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
