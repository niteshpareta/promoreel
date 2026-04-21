import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/whatsapp_share.dart';

/// A bottom sheet that shows one big chip per target app (WhatsApp, Instagram,
/// Facebook, YouTube Shorts, Telegram, more) and fires a platform-targeted
/// share intent when a chip is tapped.
///
/// Keeps the sheet open after each share so the user can broadcast to
/// multiple platforms in sequence. Chips that share successfully get a
/// ✓ marker so the user can see progress at a glance.
Future<void> showPlatformShareSheet(
  BuildContext context, {
  required String videoPath,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlatformShareSheet(videoPath: videoPath),
  );
}

class _PlatformShareSheet extends StatefulWidget {
  const _PlatformShareSheet({required this.videoPath});
  final String videoPath;

  @override
  State<_PlatformShareSheet> createState() => _PlatformShareSheetState();
}

class _PlatformShareSheetState extends State<_PlatformShareSheet> {
  Set<ShareTarget> _installed = const {};
  final Set<ShareTarget> _shared = {};
  bool _loaded = false;

  static const _candidates = [
    ShareTarget.whatsapp,
    ShareTarget.whatsappBusiness,
    ShareTarget.instagram,
    ShareTarget.facebook,
    ShareTarget.youtube,
    ShareTarget.telegram,
  ];

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    final installed = await VideoShareService.installedTargets(_candidates);
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _loaded = true;
    });
  }

  Future<void> _share(ShareTarget target) async {
    final ok = await VideoShareService.shareToTarget(target, widget.videoPath);
    if (!mounted) return;
    if (ok) setState(() => _shared.add(target));
  }

  Future<void> _shareGeneric() async {
    await VideoShareService.shareWithSystemSheet(widget.videoPath);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Share your promo', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Tap a platform — sheet stays open so you can share to more.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final target in _candidates)
                    _PlatformChip(
                      target: target,
                      installed: _installed.contains(target),
                      shared: _shared.contains(target),
                      onTap: _installed.contains(target)
                          ? () => _share(target)
                          : null,
                    ),
                ],
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _shareGeneric,
              icon: const Icon(Icons.apps_rounded),
              label: const Text('More apps'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.target,
    required this.installed,
    required this.shared,
    required this.onTap,
  });

  final ShareTarget target;
  final bool installed;
  final bool shared;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = shared
        ? AppColors.success.withValues(alpha: 0.12)
        : AppColors.bgElevated;
    final borderColor = shared ? AppColors.success : AppColors.border;
    final foregroundColor = installed ? AppColors.textPrimary : AppColors.textDisabled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: installed ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: shared ? 1.5 : 1),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconFor(target), color: foregroundColor, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    target.displayName,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: foregroundColor, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (shared)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
              if (!installed)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Icon(Icons.download_for_offline_outlined,
                      color: AppColors.textDisabled, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ShareTarget t) {
    switch (t) {
      case ShareTarget.whatsapp:
      case ShareTarget.whatsappBusiness:
        return Icons.chat_bubble_rounded;
      case ShareTarget.instagram:
        return Icons.camera_alt_rounded;
      case ShareTarget.facebook:
      case ShareTarget.facebookLite:
        return Icons.facebook_rounded;
      case ShareTarget.telegram:
        return Icons.send_rounded;
      case ShareTarget.youtube:
        return Icons.play_circle_fill_rounded;
      case ShareTarget.twitter:
        return Icons.alternate_email_rounded;
      case ShareTarget.snapchat:
        return Icons.visibility_rounded;
    }
  }
}
