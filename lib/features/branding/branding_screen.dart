import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/branding_preset.dart';
import '../../providers/branding_provider.dart';

class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key});

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  String? _logoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preset = ref.read(brandingProvider);
    _nameCtrl    = TextEditingController(text: preset.businessName);
    _phoneCtrl   = TextEditingController(text: preset.phoneNumber);
    _addressCtrl = TextEditingController(text: preset.address);
    _logoPath    = preset.logoPath;
    _nameCtrl.addListener(_rebuild);
    _phoneCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_rebuild);
    _phoneCtrl.removeListener(_rebuild);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) setState(() => _logoPath = file.path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preset = BrandingPreset(
      id: const Uuid().v4(),
      name: 'Default',
      businessName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      logoPath: _logoPath,
    );
    await ref.read(brandingProvider.notifier).save(preset);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branding saved')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Branding Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text('Save',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logo', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 12),
            _LogoPicker(path: _logoPath, onTap: _pickLogo),
            const SizedBox(height: 28),
            Text('Business Info', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: AppTextStyles.bodyMedium,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Business Name',
                prefixIcon: Icon(Icons.store_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.bodyMedium,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              style: AppTextStyles.bodySmall,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Address (optional)',
                prefixIcon: Icon(Icons.location_on_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 28),
            _PreviewCard(
              name: _nameCtrl.text,
              phone: _phoneCtrl.text,
              logoPath: _logoPath,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({this.path, required this.onTap});
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            image: path != null && File(path!).existsSync()
                ? DecorationImage(
                    image: FileImage(File(path!)), fit: BoxFit.cover)
                : null,
          ),
          child: path == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded,
                        color: AppColors.textSecondary, size: 30),
                    const SizedBox(height: 4),
                    Text('Logo',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                )
              : null,
        ),
      );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard(
      {required this.name, required this.phone, this.logoPath});
  final String name, phone;
  final String? logoPath;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview',
              style: AppTextStyles.titleSmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 5,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: name.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(8),
                              image: logoPath != null &&
                                      File(logoPath!).existsSync()
                                  ? DecorationImage(
                                      image: FileImage(File(logoPath!)),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            child: logoPath == null
                                ? const Icon(Icons.store_rounded,
                                    size: 20, color: AppColors.primary)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(name,
                                    style: AppTextStyles.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (phone.isNotEmpty)
                                  Text(phone,
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary),
                                      maxLines: 1),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text('Enter your business name',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textDisabled)),
                    ),
            ),
          ),
        ],
      );
}
