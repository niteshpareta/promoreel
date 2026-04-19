import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/motion_style.dart';
import '../../providers/project_provider.dart';

class StylePickerScreen extends ConsumerWidget {
  const StylePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    if (project == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.home));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildGrid(context, ref, project.motionStyleId)),
            _buildConfirmButton(context, ref, project.motionStyleId),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose Style', style: AppTextStyles.titleLarge),
                Text('How should your video move?',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );

  Widget _buildGrid(BuildContext context, WidgetRef ref, MotionStyleId selected) {
    final families = [
      ('Subtle', MotionStyleFamily.subtle),
      ('Energetic', MotionStyleFamily.energetic),
      ('Informational', MotionStyleFamily.informational),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: families.map((fam) {
        final styles = MotionStyle.all.where((s) => s.family == fam.$2).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text(fam.$1,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: styles.length,
              itemBuilder: (ctx, i) {
                final style = styles[i];
                final isSelected = style.id == selected;
                return GestureDetector(
                  onTap: () => ref.read(projectProvider.notifier).setMotionStyle(style.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryContainer : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          _familyIcon(style.family),
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(style.nameEn,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(style.nameHi,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary, fontSize: 10,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 18),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildConfirmButton(BuildContext context, WidgetRef ref, MotionStyleId selected) {
    final style = MotionStyle.all.firstWhere((s) => s.id == selected);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(
              'Use ${style.nameEn}',
              style: AppTextStyles.labelLarge.copyWith(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  IconData _familyIcon(MotionStyleFamily f) => switch (f) {
        MotionStyleFamily.subtle        => Icons.auto_awesome_outlined,
        MotionStyleFamily.energetic     => Icons.flash_on_rounded,
        MotionStyleFamily.informational => Icons.info_outline_rounded,
      };
}
