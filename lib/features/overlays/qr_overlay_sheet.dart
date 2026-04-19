import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/project_provider.dart';

void showQrOverlaySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _QrOverlaySheet(),
  );
}

class _QrOverlaySheet extends ConsumerStatefulWidget {
  const _QrOverlaySheet();

  @override
  ConsumerState<_QrOverlaySheet> createState() => _QrOverlaySheetState();
}

class _QrOverlaySheetState extends ConsumerState<_QrOverlaySheet> {
  late TextEditingController _ctrl;
  String _position = 'bottom_right';

  static const _positions = [
    ('bottom_right', 'Bottom Right'),
    ('bottom_left',  'Bottom Left'),
    ('top_right',    'Top Right'),
    ('top_left',     'Top Left'),
  ];

  @override
  void initState() {
    super.initState();
    final p = ref.read(projectProvider);
    _ctrl     = TextEditingController(text: p?.qrData ?? '');
    _position = p?.qrPosition ?? 'bottom_right';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final notifier = ref.read(projectProvider.notifier);
    final data = _ctrl.text.trim();
    notifier.setQrData(data.isEmpty ? null : data);
    notifier.setQrEnabled(data.isNotEmpty);
    notifier.setQrPosition(_position);
    Navigator.pop(context);
  }

  void _remove() {
    final notifier = ref.read(projectProvider.notifier);
    notifier.setQrData(null);
    notifier.setQrEnabled(false);
    _ctrl.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasData = _ctrl.text.trim().isNotEmpty;

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

          Text('QR Code Overlay', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text('Embed a scannable QR code in the video',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // QR preview + input side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live QR preview
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: hasData
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: QrImageView(
                          data: _ctrl.text.trim(),
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          size: 100,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF000000)),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF000000)),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.qr_code_rounded,
                            color: Colors.grey.shade400, size: 44),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('URL or Phone Number',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary,
                                fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'https://... or +91 XXXXX XXXXX',
                          hintStyle: TextStyle(
                              color: AppColors.textDisabled, fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Position picker
          Text('Position',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _positions.map((opt) {
              final sel = _position == opt.$1;
              return GestureDetector(
                onTap: () => setState(() => _position = opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        sel ? AppColors.primaryContainer : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.divider,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(opt.$2,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: sel
                            ? AppColors.primary
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
              if (ref.read(projectProvider)?.qrEnabled == true) ...[
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
                    child: const Text('Remove QR'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: hasData ? _apply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Apply QR Code'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
