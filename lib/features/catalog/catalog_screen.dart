import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/video_project.dart';
import '../../providers/project_provider.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _ProductEntry {
  _ProductEntry();
  String? imagePath;
  String name = '';
  String price = '';
  String mrp = '';

  bool get hasContent => name.isNotEmpty || price.isNotEmpty || imagePath != null;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final List<_ProductEntry> _entries = [_ProductEntry()];
  final List<TextEditingController> _nameCtrls   = [TextEditingController()];
  final List<TextEditingController> _priceCtrls  = [TextEditingController()];
  final List<TextEditingController> _mrpCtrls    = [TextEditingController()];

  @override
  void dispose() {
    for (final c in _nameCtrls)  c.dispose();
    for (final c in _priceCtrls) c.dispose();
    for (final c in _mrpCtrls)   c.dispose();
    super.dispose();
  }

  void _addProduct() {
    if (_entries.length >= 10) return;
    setState(() {
      _entries.add(_ProductEntry());
      _nameCtrls.add(TextEditingController());
      _priceCtrls.add(TextEditingController());
      _mrpCtrls.add(TextEditingController());
    });
  }

  void _removeProduct(int i) {
    if (_entries.length <= 1) return;
    _nameCtrls[i].dispose();
    _priceCtrls[i].dispose();
    _mrpCtrls[i].dispose();
    setState(() {
      _entries.removeAt(i);
      _nameCtrls.removeAt(i);
      _priceCtrls.removeAt(i);
      _mrpCtrls.removeAt(i);
    });
  }

  Future<void> _pickImage(int i) async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _entries[i].imagePath = img.path);
    }
  }

  void _syncControllers() {
    for (int i = 0; i < _entries.length; i++) {
      _entries[i].name  = _nameCtrls[i].text.trim();
      _entries[i].price = _priceCtrls[i].text.trim();
      _entries[i].mrp   = _mrpCtrls[i].text.trim();
    }
  }

  void _generate() {
    _syncControllers();

    final valid = _entries.where((e) => e.hasContent).toList();
    if (valid.isEmpty) return;

    final assetPaths = valid.map((e) => e.imagePath ?? kTextSlide).toList();
    final n = assetPaths.length;

    var project = VideoProject.create(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      assetPaths: assetPaths,
    ).copyWith(
      frameCaptions:   valid.map((e) => e.name).toList(),
      framePriceTags:  valid.map((e) => e.price).toList(),
      frameMrpTags:    valid.map((e) => e.mrp).toList(),
      frameDurations:  List.filled(n, 3),
      frameOfferBadges: valid
          .map((e) => e.price.isNotEmpty ? 'SALE' : '')
          .toList(),
    ).copyWithMusic('upbeat_01');

    ref.read(projectProvider.notifier).loadFrom(project);
    context.go(AppRoutes.editor);
  }

  int get _filledCount =>
      _entries.where((e) => e.hasContent).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Product Catalog',
                            style: AppTextStyles.titleLarge
                                .copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          _filledCount == 0
                              ? 'Add your products — each becomes a slide'
                              : '$_filledCount product${_filledCount == 1 ? '' : 's'} · ready to generate',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _filledCount > 0
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_entries.length < 10)
                    TextButton.icon(
                      onPressed: _addProduct,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                    ),
                ],
              ),
            ),

            // ── Tip banner ────────────────────���────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Each product becomes one slide. Image is optional — '
                      'leave blank for a text-only slide.',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // ── Products list ──────────────────────────────────────────
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _entries.length,
                onReorder: (oldIdx, newIdx) {
                  if (oldIdx < newIdx) newIdx--;
                  setState(() {
                    final e  = _entries.removeAt(oldIdx);
                    final nc = _nameCtrls.removeAt(oldIdx);
                    final pc = _priceCtrls.removeAt(oldIdx);
                    final mc = _mrpCtrls.removeAt(oldIdx);
                    _entries.insert(newIdx, e);
                    _nameCtrls.insert(newIdx, nc);
                    _priceCtrls.insert(newIdx, pc);
                    _mrpCtrls.insert(newIdx, mc);
                  });
                },
                itemBuilder: (ctx, i) => _ProductCard(
                  key: ValueKey('product_$i'),
                  index: i,
                  total: _entries.length,
                  entry: _entries[i],
                  nameCtrl: _nameCtrls[i],
                  priceCtrl: _priceCtrls[i],
                  mrpCtrl: _mrpCtrls[i],
                  onPickImage: () => _pickImage(i),
                  onRemove: _entries.length > 1
                      ? () => _removeProduct(i)
                      : null,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),

            // ── Generate button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _filledCount > 0 ? _generate : null,
                  icon: const Icon(Icons.movie_creation_rounded, size: 20),
                  label: Text(
                    _filledCount > 0
                        ? 'Generate Video  ·  $_filledCount slides'
                        : 'Add at least one product',
                    style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor:
                        AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required super.key,
    required this.index,
    required this.total,
    required this.entry,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.mrpCtrl,
    required this.onPickImage,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final int total;
  final _ProductEntry entry;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController mrpCtrl;
  final VoidCallback onPickImage;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasContent = entry.hasContent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasContent
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.divider,
          width: hasContent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker slot
            GestureDetector(
              onTap: onPickImage,
              child: Container(
                width: 72, height: 96,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entry.imagePath != null
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.divider,
                  ),
                ),
                child: entry.imagePath != null &&
                        File(entry.imagePath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(entry.imagePath!),
                                fit: BoxFit.cover),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  entry.imagePath = null;
                                  onChanged();
                                },
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.textDisabled, size: 22),
                          const SizedBox(height: 4),
                          Text('Photo',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textDisabled,
                                  fontSize: 9)),
                          Text('optional',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textDisabled,
                                  fontSize: 8)),
                        ],
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // Fields
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasContent
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasContent
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.divider,
                          ),
                        ),
                        child: Text('Product ${index + 1}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: hasContent
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            )),
                      ),
                      const Spacer(),
                      if (onRemove != null)
                        GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: AppColors.error, size: 14),
                          ),
                        ),
                      const SizedBox(width: 4),
                      // Drag handle
                      const Icon(Icons.drag_handle_rounded,
                          color: AppColors.textDisabled, size: 18),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Product name
                  _MiniField(
                    controller: nameCtrl,
                    hint: 'Product name (e.g. Samsung TV, Gold Ring…)',
                    maxLength: 60,
                    onChanged: (_) => onChanged(),
                  ),

                  const SizedBox(height: 6),

                  // Price row
                  Row(
                    children: [
                      Expanded(
                        child: _MiniField(
                          controller: mrpCtrl,
                          hint: 'MRP ₹',
                          maxLength: 10,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.textDisabled),
                      ),
                      Expanded(
                        child: _MiniField(
                          controller: priceCtrl,
                          hint: 'Offer ₹',
                          maxLength: 10,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => onChanged(),
                          highlightColor: const Color(0xFFFFB300),
                        ),
                      ),
                    ],
                  ),

                  // Savings preview
                  _SavingsChip(
                      mrp: mrpCtrl.text, price: priceCtrl.text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Savings preview chip ─────────────────────────────────────────────────��────

class _SavingsChip extends StatelessWidget {
  const _SavingsChip({required this.mrp, required this.price});
  final String mrp;
  final String price;

  @override
  Widget build(BuildContext context) {
    final mrpVal   = double.tryParse(mrp.trim());
    final priceVal = double.tryParse(price.trim());
    if (mrpVal == null || priceVal == null || mrpVal <= priceVal) {
      return const SizedBox.shrink();
    }
    final pct = ((mrpVal - priceVal) / mrpVal * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.success, size: 11),
          const SizedBox(width: 3),
          Text('$pct% off — ₹${(mrpVal - priceVal).round()} savings',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.success,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Mini input field ─────────────────────────────────────────────────────��────

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.onChanged,
    this.keyboardType,
    this.highlightColor,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: 1,
          keyboardType: keyboardType,
          style: TextStyle(
            color: highlightColor ?? AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textDisabled, fontSize: 11),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            counterText: '',
          ),
        ),
      );
}
