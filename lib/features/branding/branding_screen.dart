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
import '../../providers/subscription_provider.dart';

class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key});

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _kitNameCtrl;
  String? _logoPath;
  String? _editingKitId; // null = no saved kit yet (first kit will be created)
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final active = ref.read(brandingProvider);
    _editingKitId = ref.read(brandKitsProvider).activeId;
    _nameCtrl    = TextEditingController(text: active.businessName);
    _phoneCtrl   = TextEditingController(text: active.phoneNumber);
    _addressCtrl = TextEditingController(text: active.address);
    _kitNameCtrl = TextEditingController(text: active.name);
    _logoPath    = active.logoPath;
    _nameCtrl.addListener(_rebuild);
    _phoneCtrl.addListener(_rebuild);
    _kitNameCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_rebuild);
    _phoneCtrl.removeListener(_rebuild);
    _kitNameCtrl.removeListener(_rebuild);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _kitNameCtrl.dispose();
    super.dispose();
  }

  void _loadKitIntoForm(BrandingPreset kit) {
    setState(() {
      _editingKitId = kit.id;
      _nameCtrl.text = kit.businessName;
      _phoneCtrl.text = kit.phoneNumber;
      _addressCtrl.text = kit.address;
      _kitNameCtrl.text = kit.name;
      _logoPath = kit.logoPath;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) setState(() => _logoPath = file.path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preset = BrandingPreset(
      id: _editingKitId ?? const Uuid().v4(),
      name: _kitNameCtrl.text.trim().isEmpty ? 'Default' : _kitNameCtrl.text.trim(),
      businessName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      logoPath: _logoPath,
    );
    await ref.read(brandKitsProvider.notifier).save(preset);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branding saved')),
      );
      context.pop();
    }
  }

  void _startNewKit() {
    setState(() {
      _editingKitId = null;
      _kitNameCtrl.text = '';
      _nameCtrl.text = '';
      _phoneCtrl.text = '';
      _addressCtrl.text = '';
      _logoPath = null;
    });
  }

  Future<void> _deleteCurrentKit() async {
    final kitsState = ref.read(brandKitsProvider);
    if (_editingKitId == null || kitsState.kits.length <= 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Delete this kit?'),
        content: Text('"${_kitNameCtrl.text}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(brandKitsProvider.notifier).delete(_editingKitId!);
    if (!mounted) return;
    final next = ref.read(brandKitsProvider).active;
    if (next != null) _loadKitIntoForm(next);
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
            _KitSwitcher(
              editingKitId: _editingKitId,
              onSelect: _loadKitIntoForm,
              onNewKit: _startNewKit,
              onDelete: _deleteCurrentKit,
            ),
            const SizedBox(height: 20),
            Text('Logo', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 12),
            _LogoPicker(path: _logoPath, onTap: _pickLogo),
            const SizedBox(height: 28),
            Text('Kit name', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _kitNameCtrl,
              style: AppTextStyles.bodyMedium,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Main Shop, Branch, Event mode',
                prefixIcon: Icon(Icons.bookmark_border_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
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

/// Horizontal row of saved brand kits plus "+ New kit". Tapping a kit loads
/// it into the form; tapping the current kit's delete button removes it
/// (only available if more than one kit exists).
class _KitSwitcher extends ConsumerWidget {
  const _KitSwitcher({
    required this.editingKitId,
    required this.onSelect,
    required this.onNewKit,
    required this.onDelete,
  });

  final String? editingKitId;
  final ValueChanged<BrandingPreset> onSelect;
  final VoidCallback onNewKit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brandKitsProvider);
    final tier = ref.watch(subscriptionProvider);
    final maxKits = tier.brandingPresets;
    final canAddMore = state.kits.length < maxKits;
    final canDelete = editingKitId != null && state.kits.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Brand kits', style: AppTextStyles.headlineSmall),
            const Spacer(),
            if (canDelete)
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final kit in state.kits)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(kit.name.isEmpty ? 'Unnamed' : kit.name),
                    selected: kit.id == editingKitId,
                    onSelected: (_) => onSelect(kit),
                    selectedColor: AppColors.primary.withValues(alpha: 0.22),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(canAddMore ? 'New kit' : 'Limit reached'),
                onPressed: canAddMore ? onNewKit : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
