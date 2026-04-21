import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../providers/project_provider.dart';

class PickerScreen extends ConsumerStatefulWidget {
  const PickerScreen({super.key});

  @override
  ConsumerState<PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends ConsumerState<PickerScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchPicker());
  }

  Future<void> _launchPicker() async {
    if (mounted) setState(() => _error = null);

    try {
      final results = await ImagePicker().pickMultipleMedia(
        limit: AppConstants.maxAssetsPerVideo,
      );

      if (!mounted) return;

      if (results.isEmpty) {
        context.pop();
        return;
      }

      final paths = results
          .take(AppConstants.maxAssetsPerVideo)
          .map((f) => f.path)
          .toList();

      ref.read(projectProvider.notifier).startNew(paths);
      context.pushReplacement(AppRoutes.editor);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Select Media'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.textDisabled, size: 56),
                    const SizedBox(height: 16),
                    Text('Could not open gallery',
                        style: AppTextStyles.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _launchPicker,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
