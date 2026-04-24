import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/router/safe_pop.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../data/models/branding_preset.dart';
import '../../providers/branding_provider.dart';
import '../../providers/subscription_provider.dart';
import 'brand_strip_preview.dart';

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
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _socialCtrl;
  String? _logoPath;
  String? _editingKitId;
  bool _saving = false;

  int _primaryColor = 0;
  int _accentColor = 0;
  String _styleId = BrandingStyleId.classic;
  String _stripPosition = 'bottom';
  bool _showIntro = false;
  bool _showOutro = false;
  double _introDuration = 1.5;
  double _outroDuration = 1.5;

  // Curated palette — tuned to look good against video content. Users
  // can still pick any colour via long-press (future). For v1, six
  // presets cover most small-business brand identities.
  static const List<int> _primarySwatches = [
    0xFFF2A848, // brand ember (default)
    0xFFE53935, // red
    0xFF1E88E5, // blue
    0xFF43A047, // green
    0xFF8E24AA, // purple
    0xFF212121, // near-black
  ];
  static const List<int> _accentSwatches = [
    0xFF7C4DFF, // purple (default)
    0xFFFFCA28, // amber
    0xFF26C6DA, // cyan
    0xFFEC407A, // pink
    0xFF66BB6A, // green
    0xFFFFFFFF, // white
  ];

  @override
  void initState() {
    super.initState();
    final active = ref.read(brandingProvider);
    _editingKitId = ref.read(brandKitsProvider).activeId;
    _nameCtrl = TextEditingController(text: active.businessName);
    _phoneCtrl = TextEditingController(text: active.phoneNumber);
    _addressCtrl = TextEditingController(text: active.address);
    _kitNameCtrl = TextEditingController(text: active.name);
    _taglineCtrl = TextEditingController(text: active.tagline);
    _websiteCtrl = TextEditingController(text: active.website);
    _socialCtrl = TextEditingController(text: active.socialHandle);
    _logoPath = active.logoPath;
    _primaryColor = active.primaryColorArgb;
    _accentColor = active.accentColorArgb;
    _styleId = active.styleId;
    _stripPosition = active.stripPosition;
    _showIntro = active.showIntro;
    _showOutro = active.showOutro;
    _introDuration = active.introDuration;
    _outroDuration = active.outroDuration;
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _addressCtrl,
      _kitNameCtrl,
      _taglineCtrl,
      _websiteCtrl,
      _socialCtrl,
    ]) {
      c.addListener(_rebuild);
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _addressCtrl,
      _kitNameCtrl,
      _taglineCtrl,
      _websiteCtrl,
      _socialCtrl,
    ]) {
      c.removeListener(_rebuild);
      c.dispose();
    }
    super.dispose();
  }

  BrandingPreset _currentPreset({String? id}) => BrandingPreset(
        id: id ?? _editingKitId ?? 'preview',
        name: _kitNameCtrl.text.trim().isEmpty
            ? 'Default'
            : _kitNameCtrl.text.trim(),
        businessName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        logoPath: _logoPath,
        tagline: _taglineCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        socialHandle: _socialCtrl.text.trim(),
        primaryColorArgb: _primaryColor,
        accentColorArgb: _accentColor,
        styleId: _styleId,
        stripPosition: _stripPosition,
        showIntro: _showIntro,
        showOutro: _showOutro,
        introDuration: _introDuration,
        outroDuration: _outroDuration,
      );

  void _loadKitIntoForm(BrandingPreset kit) {
    setState(() {
      _editingKitId = kit.id;
      _nameCtrl.text = kit.businessName;
      _phoneCtrl.text = kit.phoneNumber;
      _addressCtrl.text = kit.address;
      _kitNameCtrl.text = kit.name;
      _taglineCtrl.text = kit.tagline;
      _websiteCtrl.text = kit.website;
      _socialCtrl.text = kit.socialHandle;
      _logoPath = kit.logoPath;
      _primaryColor = kit.primaryColorArgb;
      _accentColor = kit.accentColorArgb;
      _styleId = kit.styleId;
      _stripPosition = kit.stripPosition;
      _showIntro = kit.showIntro;
      _showOutro = kit.showOutro;
      _introDuration = kit.introDuration;
      _outroDuration = kit.outroDuration;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) setState(() => _logoPath = file.path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preset = _currentPreset(id: _editingKitId ?? const Uuid().v4());
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
      _taglineCtrl.text = '';
      _websiteCtrl.text = '';
      _socialCtrl.text = '';
      _logoPath = null;
      _primaryColor = 0;
      _accentColor = 0;
      _styleId = BrandingStyleId.classic;
      _stripPosition = 'bottom';
      _showIntro = false;
      _showOutro = false;
      _introDuration = 1.5;
      _outroDuration = 1.5;
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
    final preset = _currentPreset();
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Branding Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => safePop(context),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
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
            const SizedBox(height: 24),
            _sectionHeader('Logo'),
            const SizedBox(height: 12),
            _LogoPicker(path: _logoPath, onTap: _pickLogo),
            const SizedBox(height: 24),
            _sectionHeader('Kit name'),
            const SizedBox(height: 12),
            _textField(_kitNameCtrl,
                hint: 'e.g. Main Shop, Branch, Event mode',
                icon: Icons.bookmark_border_rounded),
            const SizedBox(height: 24),
            _sectionHeader('Business info'),
            const SizedBox(height: 12),
            _textField(_nameCtrl,
                hint: 'Business Name', icon: Icons.store_rounded),
            const SizedBox(height: 12),
            _textField(_phoneCtrl,
                hint: 'Phone Number',
                icon: Icons.phone_rounded,
                keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _textField(_addressCtrl,
                hint: 'Address (optional)',
                icon: Icons.location_on_rounded,
                maxLines: 2),
            const SizedBox(height: 24),
            _sectionHeader('Brand voice'),
            const SizedBox(height: 4),
            Text('Appears on intro / outro cards',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _textField(_taglineCtrl,
                hint: 'Tagline — e.g. "Since 1998" / "Book now"',
                icon: Icons.format_quote_rounded),
            const SizedBox(height: 12),
            _textField(_socialCtrl,
                hint: '@handle or social tag',
                icon: Icons.alternate_email_rounded),
            const SizedBox(height: 12),
            _textField(_websiteCtrl,
                hint: 'Website (optional)',
                icon: Icons.language_rounded,
                keyboard: TextInputType.url),
            const SizedBox(height: 28),
            _sectionHeader('Brand colors'),
            const SizedBox(height: 12),
            _ColorRow(
              label: 'PRIMARY',
              selectedArgb: _primaryColor,
              swatches: _primarySwatches,
              onPick: (c) => setState(() => _primaryColor = c),
            ),
            const SizedBox(height: 12),
            _ColorRow(
              label: 'ACCENT',
              selectedArgb: _accentColor,
              swatches: _accentSwatches,
              onPick: (c) => setState(() => _accentColor = c),
            ),
            const SizedBox(height: 28),
            _sectionHeader('Strip style'),
            const SizedBox(height: 12),
            _StylePicker(
              preset: preset,
              selected: _styleId,
              onSelect: (s) => setState(() => _styleId = s),
            ),
            const SizedBox(height: 20),
            _PositionToggle(
              current: _stripPosition,
              onChange: (p) => setState(() => _stripPosition = p),
            ),
            const SizedBox(height: 28),
            _sectionHeader('Intro / outro card'),
            const SizedBox(height: 4),
            Text(
              'Full-frame brand reveal at the start and/or end of every video.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _IntroOutroBlock(
              preset: preset,
              showIntro: _showIntro,
              showOutro: _showOutro,
              onToggleIntro: (v) => setState(() => _showIntro = v),
              onToggleOutro: (v) => setState(() => _showOutro = v),
            ),
            const SizedBox(height: 28),
            _sectionHeader('Live preview'),
            const SizedBox(height: 12),
            _VideoPreviewCard(preset: preset),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) =>
      Text(label, style: AppTextStyles.headlineSmall);

  Widget _textField(
    TextEditingController c, {
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: AppTextStyles.bodyMedium,
      textInputAction:
          maxLines == 1 ? TextInputAction.next : TextInputAction.done,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Logo picker ──────────────────────────────────────────────────────────────

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

// ── Color row ────────────────────────────────────────────────────────────────

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.selectedArgb,
    required this.swatches,
    required this.onPick,
  });

  final String label;
  final int selectedArgb;
  final List<int> swatches;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              )),
        ),
        for (final s in swatches) ...[
          _SwatchDot(
            argb: s,
            active: s == selectedArgb ||
                (selectedArgb == 0 && s == swatches.first),
            onTap: () {
              PrHaptics.tap();
              // Default swatch is a shortcut for "clear" (store 0 so
              // the compositor falls back to its own default if we
              // ever change the default colour).
              onPick(s == swatches.first ? 0 : s);
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot(
      {required this.argb, required this.active, required this.onTap});
  final int argb;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? Colors.white : AppColors.divider,
              width: active ? 3 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Color(argb).withValues(alpha: 0.6),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        ),
      );
}

// ── Style picker ─────────────────────────────────────────────────────────────

class _StylePicker extends StatelessWidget {
  const _StylePicker({
    required this.preset,
    required this.selected,
    required this.onSelect,
  });

  final BrandingPreset preset;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final id in BrandingStyleId.all) ...[
            _StyleTile(
              id: id,
              preset: preset,
              active: selected == id,
              onTap: () {
                PrHaptics.tap();
                onSelect(id);
              },
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.id,
    required this.preset,
    required this.active,
    required this.onTap,
  });
  final String id;
  final BrandingPreset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Mini preview forced to this tile's style regardless of which style
    // the preset currently has selected — lets the user compare before
    // committing.
    final tilePreset = preset.copyWith(styleId: id);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.divider,
                width: active ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF1B1B2B)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: BrandStripPreview(
                      preset: tilePreset,
                      width: 140,
                      heightFraction: 0.18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            BrandingStyleId.labelOf(id),
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Position toggle ─────────────────────────────────────────────────────────

class _PositionToggle extends StatelessWidget {
  const _PositionToggle({required this.current, required this.onChange});
  final String current;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    Widget opt(String val, String label, IconData icon) {
      final active = current == val;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            PrHaptics.tap();
            onChange(val);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.divider,
                width: active ? 1.4 : 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: active
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 16),
                const SizedBox(width: 8),
                Text(label,
                    style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opt('bottom', 'Bottom', Icons.south_rounded),
        opt('top', 'Top', Icons.north_rounded),
      ],
    );
  }
}

// ── Intro/outro block ────────────────────────────────────────────────────────

class _IntroOutroBlock extends StatelessWidget {
  const _IntroOutroBlock({
    required this.preset,
    required this.showIntro,
    required this.showOutro,
    required this.onToggleIntro,
    required this.onToggleOutro,
  });

  final BrandingPreset preset;
  final bool showIntro;
  final bool showOutro;
  final ValueChanged<bool> onToggleIntro;
  final ValueChanged<bool> onToggleOutro;

  @override
  Widget build(BuildContext context) {
    Widget card(String title, bool active, ValueChanged<bool> onChange,
        Widget preview) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.titleSmall
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
                Switch(
                  value: active,
                  onChanged: (v) {
                    PrHaptics.tap();
                    onChange(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: active ? 1 : 0.45,
              child: preview,
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card('Intro', showIntro, onToggleIntro,
            BrandCardPreview(preset: preset)),
        const SizedBox(width: 14),
        card('Outro', showOutro, onToggleOutro,
            BrandCardPreview(preset: preset, isOutro: true)),
      ],
    );
  }
}

// ── Video-frame preview ──────────────────────────────────────────────────────

class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({required this.preset});
  final BrandingPreset preset;

  @override
  Widget build(BuildContext context) {
    final topAnchored = preset.stripPosition == 'top';
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.6,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2A2840),
                        const Color(0xFF0E0E18),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.22),
                    size: 64,
                  ),
                ),
                if (preset.businessName.isNotEmpty)
                  LayoutBuilder(builder: (ctx, box) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: topAnchored ? 0 : null,
                      bottom: topAnchored ? null : 0,
                      child: BrandStripPreview(
                        preset: preset,
                        width: box.maxWidth,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Kit switcher ─────────────────────────────────────────────────────────────

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
                    selectedColor:
                        AppColors.primary.withValues(alpha: 0.22),
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
