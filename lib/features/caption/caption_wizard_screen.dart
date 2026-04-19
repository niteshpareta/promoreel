import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/video_project.dart';
import '../../providers/project_provider.dart';

// ── Templates ─────────────────────────────────────────────────────────────────

class _Template {
  const _Template(this.icon, this.label, this.badge, this.duration, this.color);
  final IconData icon;
  final String label;
  final String badge;
  final int duration;
  final Color color;
}

const _templates = [
  _Template(Icons.bolt_rounded,           'Flash Sale',  '50% OFF',    2, Color(0xFFFF6E40)),
  _Template(Icons.auto_awesome_rounded,   'New Arrival', 'NEW',        3, Color(0xFF00C853)),
  _Template(Icons.currency_rupee_rounded, 'Price Drop',  'SALE',       2, Color(0xFFFFB300)),
  _Template(Icons.campaign_rounded,       'Today Only',  'TODAY ONLY', 3, Color(0xFF00BCD4)),
  _Template(Icons.local_fire_department_rounded, 'Hot Deal', 'HOT',    2, Color(0xFFFF3D00)),
  _Template(Icons.celebration_rounded,   'Festival',    'LIMITED',     3, Color(0xFF7C4DFF)),
];

// ── Badge options ─────────────────────────────────────────────────────────────

const _badges = [
  ('SALE',       Color(0xFFFF6E40), Color(0xFF3A1800)),
  ('NEW',        Color(0xFF00C853), Color(0xFF003318)),
  ('HOT',        Color(0xFFFF3D00), Color(0xFF3A0A00)),
  ('50% OFF',    Color(0xFF7C4DFF), Color(0xFF1E0A4A)),
  ('LIMITED',    Color(0xFFFFB300), Color(0xFF3A2800)),
  ('TODAY ONLY', Color(0xFF00BCD4), Color(0xFF002A30)),
];

const _durations = [2, 3, 5];

// ── Screen ────────────────────────────────────────────────────────────────────

class CaptionWizardScreen extends ConsumerStatefulWidget {
  const CaptionWizardScreen({super.key});

  @override
  ConsumerState<CaptionWizardScreen> createState() =>
      _CaptionWizardScreenState();
}

class _CaptionWizardScreenState extends ConsumerState<CaptionWizardScreen> {
  List<TextEditingController> _captionCtrls = [];
  List<TextEditingController> _priceCtrls = [];
  List<TextEditingController> _mrpCtrls = [];
  List<FocusNode> _captionFocusNodes = [];
  List<FocusNode> _priceFocusNodes = [];
  List<FocusNode> _mrpFocusNodes = [];
  String? _activeTemplate;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final project = ref.read(projectProvider);
    if (project == null) return;
    final n = project.assetPaths.length;

    _captionCtrls = List.generate(n, (i) {
      final t = i < project.frameCaptions.length ? project.frameCaptions[i] : '';
      return TextEditingController(text: t);
    });
    _priceCtrls = List.generate(n, (i) {
      final t = i < project.framePriceTags.length ? project.framePriceTags[i] : '';
      return TextEditingController(text: t);
    });
    _mrpCtrls = List.generate(n, (i) {
      final t = i < project.frameMrpTags.length ? project.frameMrpTags[i] : '';
      return TextEditingController(text: t);
    });
    _captionFocusNodes = List.generate(n, (_) => FocusNode());
    _priceFocusNodes   = List.generate(n, (_) => FocusNode());
    _mrpFocusNodes     = List.generate(n, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _captionCtrls) c.dispose();
    for (final c in _priceCtrls)   c.dispose();
    for (final c in _mrpCtrls)     c.dispose();
    for (final f in _captionFocusNodes) f.dispose();
    for (final f in _priceFocusNodes)   f.dispose();
    for (final f in _mrpFocusNodes)     f.dispose();
    super.dispose();
  }

  void _saveAll() {
    for (int i = 0; i < _captionCtrls.length; i++) {
      ref.read(projectProvider.notifier).setFrameCaption(i,  _captionCtrls[i].text.trim());
      ref.read(projectProvider.notifier).setFramePriceTag(i, _priceCtrls[i].text.trim());
      ref.read(projectProvider.notifier).setFrameMrpTag(i,   _mrpCtrls[i].text.trim());
    }
  }

  void _removeFrame(int index) {
    _captionCtrls[index].dispose();
    _captionCtrls.removeAt(index);
    _priceCtrls[index].dispose();
    _priceCtrls.removeAt(index);
    _mrpCtrls[index].dispose();
    _mrpCtrls.removeAt(index);
    _captionFocusNodes[index].dispose();
    _captionFocusNodes.removeAt(index);
    _priceFocusNodes[index].dispose();
    _priceFocusNodes.removeAt(index);
    _mrpFocusNodes[index].dispose();
    _mrpFocusNodes.removeAt(index);
    ref.read(projectProvider.notifier).removeFrame(index);
    setState(() {});
  }

  void _applyToAll(int fromIndex) {
    final caption = _captionCtrls[fromIndex].text.trim();
    final price   = _priceCtrls[fromIndex].text.trim();
    final mrp     = _mrpCtrls[fromIndex].text.trim();
    final project = ref.read(projectProvider)!;
    final badge   = fromIndex < project.frameOfferBadges.length
        ? project.frameOfferBadges[fromIndex] : '';

    if (caption.isNotEmpty) {
      for (int i = 0; i < _captionCtrls.length; i++) {
        if (i != fromIndex) _captionCtrls[i].text = caption;
      }
    }
    if (price.isNotEmpty) {
      for (int i = 0; i < _priceCtrls.length; i++) {
        if (i != fromIndex) _priceCtrls[i].text = price;
      }
    }
    if (mrp.isNotEmpty) {
      for (int i = 0; i < _mrpCtrls.length; i++) {
        if (i != fromIndex) _mrpCtrls[i].text = mrp;
      }
    }

    ref.read(projectProvider.notifier).applyToAll(
      caption:  caption.isNotEmpty ? caption : null,
      priceTag: price.isNotEmpty   ? price   : null,
      mrpTag:   mrp.isNotEmpty     ? mrp     : null,
      badge:    badge.isNotEmpty   ? badge   : null,
    );
    setState(() {});
  }

  void _applyTemplate(_Template t) {
    setState(() => _activeTemplate = t.label);
    ref.read(projectProvider.notifier).applyTemplate(
      badge: t.badge,
      duration: t.duration,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    ref.read(projectProvider.notifier).reorderFrames(oldIndex, newIndex);

    // mirror reorder in local controllers
    final cc = _captionCtrls.removeAt(oldIndex);
    _captionCtrls.insert(newIndex, cc);
    final pc = _priceCtrls.removeAt(oldIndex);
    _priceCtrls.insert(newIndex, pc);
    final mc = _mrpCtrls.removeAt(oldIndex);
    _mrpCtrls.insert(newIndex, mc);
    final cf = _captionFocusNodes.removeAt(oldIndex);
    _captionFocusNodes.insert(newIndex, cf);
    final pf = _priceFocusNodes.removeAt(oldIndex);
    _priceFocusNodes.insert(newIndex, pf);
    final mf = _mrpFocusNodes.removeAt(oldIndex);
    _mrpFocusNodes.insert(newIndex, mf);

    setState(() {});
  }

  static const _videoExts = {'.mp4', '.mov', '.3gp', '.mkv', '.avi', '.webm'};
  static bool _isVideoPath(String path) {
    final idx = path.lastIndexOf('.');
    return idx >= 0 && _videoExts.contains(path.substring(idx).toLowerCase());
  }

  void _showFullPreview({
    required String path,
    required String caption,
    required String priceTag,
    required String mrpTag,
    required String offerBadge,
    required String textPosition,
    required String badgeSize,
  }) {
    final isVideo = _isVideoPath(path);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: isVideo
                    ? _FullscreenVideoPreview(
                        path: path,
                        caption: caption,
                        priceTag: priceTag,
                        mrpTag: mrpTag,
                        offerBadge: offerBadge,
                        textPosition: textPosition,
                        badgeSize: badgeSize,
                      )
                    : _LiveThumbnail(
                        path: path,
                        caption: caption,
                        priceTag: priceTag,
                        mrpTag: mrpTag,
                        offerBadge: offerBadge,
                        badgeSize: badgeSize,
                        textPosition: textPosition,
                        fullSize: true,
                      ),
              ),
            ),
            Positioned(
              top: -14, right: -14,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _done() {
    _saveAll();
    context.pop(); // return to Editor
  }

  int get _customizedCount {
    int count = 0;
    for (int i = 0; i < _captionCtrls.length; i++) {
      if (_captionCtrls[i].text.isNotEmpty || _priceCtrls[i].text.isNotEmpty) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    if (project == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.home));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final paths = project.assetPaths;
    final total = paths.length;
    if (_captionCtrls.length != total || _mrpCtrls.length != total) _initControllers();

    final customized = _customizedCount;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Top bar ────────────────────────────────────────────────
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
                        Text('Customize Frames',
                            style: AppTextStyles.titleLarge
                                .copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          customized == 0
                              ? 'Caption · Price · Badge · Position · Order'
                              : '$customized of $total frames customized',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: customized > 0
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _done,
                    child: Text('Skip',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),

            // ── Quick template strip ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 18, bottom: 7),
                    child: Text('Quick Setup',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  ),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _templates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final t = _templates[i];
                        final active = _activeTemplate == t.label;
                        return GestureDetector(
                          onTap: () => _applyTemplate(t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? t.color.withValues(alpha: 0.18)
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? t.color
                                    : AppColors.divider,
                                width: active ? 1.5 : 1,
                              ),
                              boxShadow: active
                                  ? [BoxShadow(
                                      color: t.color.withValues(alpha: 0.25),
                                      blurRadius: 10)]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(t.icon,
                                    size: 22,
                                    color: active ? t.color : AppColors.textSecondary),
                                const SizedBox(height: 4),
                                Text(t.label,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: active ? t.color : AppColors.textSecondary,
                                      fontWeight: active
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      fontSize: 10,
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Text animation style ────────────────────────────────────
            _TextAnimStylePicker(
              selected: project.textAnimStyle,
              onSelected: (s) =>
                  ref.read(projectProvider.notifier).setTextAnimStyle(s),
            ),

            // ── Frames list ─────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                itemCount: total,
                itemBuilder: (ctx, i) {
                  final project2 = ref.read(projectProvider)!;
                  return _FrameCard(
                    key: ValueKey('frame_$i'),
                    index: i,
                    total: total,
                    path: paths[i],
                    captionCtrl: _captionCtrls[i],
                    priceCtrl: _priceCtrls[i],
                    mrpCtrl: _mrpCtrls[i],
                    captionFocus: _captionFocusNodes[i],
                    priceFocus: _priceFocusNodes[i],
                    mrpFocus: _mrpFocusNodes[i],
                    mrpTag: i < project2.frameMrpTags.length
                        ? project2.frameMrpTags[i] : '',
                    offerBadge: i < project2.frameOfferBadges.length
                        ? project2.frameOfferBadges[i] : '',
                    badgeSize: i < project2.frameBadgeSizes.length
                        ? project2.frameBadgeSizes[i] : 'medium',
                    duration: i < project2.frameDurations.length
                        ? project2.frameDurations[i] : 3,
                    textPosition: i < project2.frameTextPositions.length
                        ? project2.frameTextPositions[i] : 'bottom',
                    onCaptionChanged: (v) {
                      ref.read(projectProvider.notifier).setFrameCaption(i, v);
                      setState(() {});
                    },
                    onPriceChanged: (v) {
                      ref.read(projectProvider.notifier).setFramePriceTag(i, v);
                      setState(() {});
                    },
                    onMrpChanged: (v) {
                      ref.read(projectProvider.notifier).setFrameMrpTag(i, v);
                      setState(() {});
                    },
                    onBadgeSelected: (b) {
                      ref.read(projectProvider.notifier).setFrameOfferBadge(i, b);
                      setState(() {});
                    },
                    onBadgeSizeSelected: (s) {
                      ref.read(projectProvider.notifier).setFrameBadgeSize(i, s);
                      setState(() {});
                    },
                    onDurationSelected: (d) {
                      ref.read(projectProvider.notifier).setFrameDuration(i, d);
                      setState(() {});
                    },
                    onPositionSelected: (p) {
                      ref.read(projectProvider.notifier).setFrameTextPosition(i, p);
                      setState(() {});
                    },
                    onMoveUp: i > 0 ? () => _onReorder(i, i - 1) : null,
                    onMoveDown: i < total - 1 ? () => _onReorder(i, i + 1) : null,
                    onRemove: total > 1 ? () => _removeFrame(i) : null,
                    onApplyToAll: total > 1 ? () => _applyToAll(i) : null,
                    onPreview: () => _showFullPreview(
                      path: paths[i],
                      caption: _captionCtrls[i].text,
                      priceTag: _priceCtrls[i].text,
                      mrpTag: _mrpCtrls[i].text,
                      offerBadge: project2.frameOfferBadges.length > i
                          ? project2.frameOfferBadges[i] : '',
                      textPosition: project2.frameTextPositions.length > i
                          ? project2.frameTextPositions[i] : 'bottom',
                      badgeSize: project2.frameBadgeSizes.length > i
                          ? project2.frameBadgeSizes[i] : 'medium',
                    ),
                  );
                },
              ),
            ),

            // ── Generate button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ).copyWith(
                    elevation: WidgetStateProperty.all(8),
                    shadowColor: WidgetStateProperty.all(
                        AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.movie_creation_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        customized > 0
                            ? 'Generate Video  ·  $customized customized'
                            : 'Generate My Video',
                        style: AppTextStyles.labelLarge.copyWith(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
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

// ── Text animation style picker ───────────────────────────────────────────────

class _TextAnimStylePicker extends StatelessWidget {
  const _TextAnimStylePicker(
      {required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = [
    ('none',     Icons.text_fields_rounded,         'None'),
    ('fade',     Icons.wb_sunny_outlined,           'Fade In'),
    ('slide_up', Icons.keyboard_double_arrow_up_rounded, 'Slide Up'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 7),
            child: Text('Text Entrance Animation',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          Row(
            children: _options.map((opt) {
              final active = selected == opt.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: EdgeInsets.only(
                        right: opt.$1 == 'slide_up' ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryContainer
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : AppColors.divider,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(opt.$2,
                            size: 18,
                            color: active
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(height: 3),
                        Text(opt.$3,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textDisabled,
                              fontSize: 9,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Frame card ────────────────────────────────────────────────────────────────

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required super.key,
    required this.index,
    required this.total,
    required this.path,
    required this.captionCtrl,
    required this.priceCtrl,
    required this.mrpCtrl,
    required this.captionFocus,
    required this.priceFocus,
    required this.mrpFocus,
    required this.mrpTag,
    required this.offerBadge,
    required this.badgeSize,
    required this.duration,
    required this.textPosition,
    required this.onCaptionChanged,
    required this.onPriceChanged,
    required this.onMrpChanged,
    required this.onBadgeSelected,
    required this.onBadgeSizeSelected,
    required this.onDurationSelected,
    required this.onPositionSelected,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onApplyToAll,
    this.onPreview,
  });

  final int index;
  final int total;
  final String path;
  final TextEditingController captionCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController mrpCtrl;
  final FocusNode captionFocus;
  final FocusNode priceFocus;
  final FocusNode mrpFocus;
  final String mrpTag;
  final String offerBadge;
  final String badgeSize;
  final int duration;
  final String textPosition;
  final ValueChanged<String> onCaptionChanged;
  final ValueChanged<String> onPriceChanged;
  final ValueChanged<String> onMrpChanged;
  final ValueChanged<String> onBadgeSelected;
  final ValueChanged<String> onBadgeSizeSelected;
  final ValueChanged<int> onDurationSelected;
  final ValueChanged<String> onPositionSelected;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final VoidCallback? onApplyToAll;
  final VoidCallback? onPreview;

  bool get _hasAny =>
      captionCtrl.text.isNotEmpty ||
      priceCtrl.text.isNotEmpty  ||
      mrpCtrl.text.isNotEmpty    ||
      offerBadge.isNotEmpty;

  // Savings chip data
  String? get _savingsText {
    final mrp   = double.tryParse(mrpCtrl.text.trim());
    final offer = double.tryParse(priceCtrl.text.trim());
    if (mrp == null || offer == null || mrp <= offer) return null;
    final saved = (mrp - offer).round();
    final pct   = ((mrp - offer) / mrp * 100).round();
    return 'You save ₹$saved ($pct% off)';
  }

  @override
  Widget build(BuildContext context) {
    final savings = _savingsText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _hasAny
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.divider,
          width: _hasAny ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _hasAny
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: _hasAny ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Header bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
            child: Row(
              children: [
                // Photo number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _hasAny
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasAny
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasAny) ...[
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 12),
                        const SizedBox(width: 5),
                      ],
                      Text('Photo ${index + 1}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _hasAny
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                const Spacer(),
                _MoveButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  enabled: index > 0,
                  onTap: () => onMoveUp?.call(),
                ),
                _MoveButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  enabled: index < total - 1,
                  onTap: () => onMoveDown?.call(),
                ),
                if (onRemove != null)
                  GestureDetector(
                    onTap: () => onRemove?.call(),
                    child: Container(
                      width: 32, height: 32,
                      margin: const EdgeInsets.only(left: 4, right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Full-width 9:16 live preview (max 340dp tall) ─────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: onPreview,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _LiveThumbnail(
                        path: path,
                        caption: captionCtrl.text,
                        priceTag: priceCtrl.text,
                        mrpTag: mrpCtrl.text,
                        offerBadge: offerBadge,
                        badgeSize: badgeSize,
                        textPosition: textPosition,
                        fullSize: true,
                      ),
                      // Fullscreen hint — bottom-right corner
                      Positioned(
                        bottom: 10, right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Fullscreen',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      // LIVE badge — top-left corner
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Controls ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Caption ──────────────────────────────────────────
                _SectionLabel(Icons.title_rounded, 'Caption'),
                const SizedBox(height: 8),
                _InputField(
                  controller: captionCtrl,
                  focusNode: captionFocus,
                  hint: 'e.g. New Stock, Sale Today...',
                  maxLength: 60,
                  maxLines: 2,
                  onChanged: onCaptionChanged,
                ),
                const SizedBox(height: 10),
                // Text position picker sits right below caption
                _TextPositionPicker(
                  selected: textPosition,
                  onSelected: onPositionSelected,
                ),
                if (captionCtrl.text.isNotEmpty && onApplyToAll != null) ...[
                  const SizedBox(height: 6),
                  _ApplyToAllLink(onTap: onApplyToAll!),
                ],

                const SizedBox(height: 18),
                _Divider(),
                const SizedBox(height: 18),

                // ── Price ─────────────────────────────────────────────
                _SectionLabel(Icons.currency_rupee_rounded, 'Price Tag'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MRP / Was',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textDisabled,
                                  fontSize: 10)),
                          const SizedBox(height: 4),
                          _InputField(
                            controller: mrpCtrl,
                            focusNode: mrpFocus,
                            hint: '999',
                            prefix: '₹',
                            maxLength: 10,
                            maxLines: 1,
                            onChanged: onMrpChanged,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: AppColors.textDisabled),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Offer Price',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: const Color(0xFFFFB300),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          _InputField(
                            controller: priceCtrl,
                            focusNode: priceFocus,
                            hint: '499',
                            prefix: '₹',
                            maxLength: 10,
                            maxLines: 1,
                            onChanged: onPriceChanged,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Savings chip
                if (savings != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        const Color(0xFF00C853).withValues(alpha: 0.15),
                        const Color(0xFF00C853).withValues(alpha: 0.05),
                      ]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00C853).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFF00C853), size: 14),
                        const SizedBox(width: 6),
                        Text(savings,
                            style: const TextStyle(
                              color: Color(0xFF00C853),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ],
                if ((priceCtrl.text.isNotEmpty || mrpCtrl.text.isNotEmpty)
                    && onApplyToAll != null) ...[
                  const SizedBox(height: 6),
                  _ApplyToAllLink(onTap: onApplyToAll!),
                ],

                const SizedBox(height: 18),
                _Divider(),
                const SizedBox(height: 18),

                // ── Offer badge ───────────────────────────────────────
                _SectionLabel(Icons.local_offer_rounded, 'Offer Badge'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BadgeChip(
                      label: 'None',
                      textColor: AppColors.textSecondary,
                      bgColor: AppColors.bgElevated,
                      borderColor: offerBadge.isEmpty
                          ? AppColors.primary
                          : AppColors.divider,
                      isSelected: offerBadge.isEmpty,
                      onTap: () => onBadgeSelected(''),
                    ),
                    ..._badges.map((b) => _BadgeChip(
                      label: b.$1,
                      textColor: b.$2,
                      bgColor: b.$3,
                      borderColor: offerBadge == b.$1
                          ? b.$2
                          : b.$2.withValues(alpha: 0.25),
                      isSelected: offerBadge == b.$1,
                      onTap: () =>
                          onBadgeSelected(offerBadge == b.$1 ? '' : b.$1),
                    )),
                  ],
                ),

                const SizedBox(height: 18),
                _Divider(),
                const SizedBox(height: 14),

                // ── Badge size ────────────────────────────────────────
                Row(
                  children: [
                    _SectionLabel(Icons.format_size_rounded, 'Badge Size'),
                    const Spacer(),
                    ...[ ('small', 'S'), ('medium', 'M'), ('large', 'L') ].map((opt) {
                      final sel = badgeSize == opt.$1;
                      return GestureDetector(
                        onTap: () => onBadgeSizeSelected(opt.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(left: 6),
                          width: 36,
                          height: 30,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primaryContainer : AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? AppColors.primary : AppColors.divider,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(opt.$2,
                            style: TextStyle(
                              color: sel ? AppColors.primary : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                            )),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 18),
                _Divider(),
                const SizedBox(height: 18),

                // ── Slide duration ────────────────────────────────────
                _SectionLabel(Icons.timer_rounded, 'Slide Duration'),
                const SizedBox(height: 10),
                Row(
                  children: _durations.map((d) {
                    final sel = duration == d;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onDurationSelected(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(
                              right: d == _durations.last ? 0 : 8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primaryContainer
                                : AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text('${d}s',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: sel
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    fontSize: 18,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                d == 2 ? 'Quick' : d == 3 ? 'Normal' : 'Slow',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.textDisabled,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Text position picker ──────────────────────────────────────────────────────

class _TextPositionPicker extends StatelessWidget {
  const _TextPositionPicker({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = [
    ('top',    Icons.vertical_align_top_rounded,    'Top'),
    ('center', Icons.vertical_align_center_rounded, 'Middle'),
    ('bottom', Icons.vertical_align_bottom_rounded, 'Bottom'),
  ];

  @override
  Widget build(BuildContext context) => Row(
        children: _options.map((opt) {
          final active = selected == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: EdgeInsets.only(
                    right: opt.$1 == 'bottom' ? 0 : 6),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryContainer
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.divider,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(opt.$2,
                        size: 16,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(height: 2),
                    Text(opt.$3,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: active
                              ? AppColors.primary
                              : AppColors.textDisabled,
                          fontSize: 9,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ── Live thumbnail ────────────────────────────────────────────────────────────

class _LiveThumbnail extends StatefulWidget {
  const _LiveThumbnail({
    required this.path,
    required this.caption,
    required this.priceTag,
    required this.mrpTag,
    required this.offerBadge,
    required this.textPosition,
    this.badgeSize = 'medium',
    this.fullSize = false,
  });
  final String path;
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;
  final bool fullSize;

  @override
  State<_LiveThumbnail> createState() => _LiveThumbnailState();
}

class _LiveThumbnailState extends State<_LiveThumbnail> {
  static const _videoExts = {'.mp4', '.mov', '.3gp', '.mkv', '.avi', '.webm'};

  Uint8List? _videoThumb;
  bool _loadingThumb = false;

  bool get _isVideo {
    final idx = widget.path.lastIndexOf('.');
    if (idx < 0) return false;
    return _videoExts.contains(widget.path.substring(idx).toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) _loadThumb();
  }

  @override
  void didUpdateWidget(_LiveThumbnail old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _videoThumb = null;
      if (_isVideo) _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    if (_loadingThumb) return;
    _loadingThumb = true;
    try {
      final thumb = await VideoThumbnail.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 80,
      );
      if (mounted && thumb != null) setState(() => _videoThumb = thumb);
    } catch (_) {}
    _loadingThumb = false;
  }

  @override
  Widget build(BuildContext context) {
    // Proxy all widget fields via widget.xxx
    final path        = widget.path;
    final caption     = widget.caption;
    final priceTag    = widget.priceTag;
    final mrpTag      = widget.mrpTag;
    final offerBadge  = widget.offerBadge;
    final textPosition= widget.textPosition;
    final badgeSize   = widget.badgeSize;
    final fullSize    = widget.fullSize;
    final badgeData = offerBadge.isNotEmpty
        ? _badges.where((b) => b.$1 == offerBadge).firstOrNull
        : null;

    const Map<String, double> _sizeFactors = {
      'small': 0.65, 'medium': 1.0, 'large': 1.50,
    };
    final sf = _sizeFactors[badgeSize] ?? 1.0;

    final captionFontSize = fullSize ? 16.0 : 7.0;
    final badgeFontSize   = (fullSize ? 11.0 : 6.0) * sf;
    final priceFontSize   = (fullSize ? 12.0 : 7.0) * sf;
    final badgePadH       = (fullSize ? 8.0  : 4.0) * sf;
    final badgePadV       = (fullSize ? 4.0  : 2.0) * sf;
    final edgeInset       = fullSize ? 12.0 : 5.0;

    // Approximate badge height for overlap avoidance when position == top
    final hasBadgeOverlay = priceTag.isNotEmpty || mrpTag.isNotEmpty || offerBadge.isNotEmpty;
    final badgeRowH = badgeFontSize + badgePadV * 2 + (fullSize ? 6.0 : 2.0);

    final Widget content = Stack(
      fit: StackFit.expand,
      children: [
        _buildImage(),

        if (caption.isNotEmpty)
          if (textPosition == 'center')
            // Semi-transparent band in the vertical center
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: fullSize ? 120 : 40,
                  decoration: const BoxDecoration(
                    color: Color(0x88000000),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: textPosition == 'top'
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  end: textPosition == 'top'
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  colors: const [Colors.transparent, Color(0xCC000000)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

        if (caption.isNotEmpty)
          if (textPosition == 'center')
            Positioned.fill(
              left: edgeInset, right: edgeInset,
              child: Center(child: _captionText(caption, captionFontSize)),
            )
          else
            Positioned(
              left: edgeInset, right: edgeInset,
              top: textPosition == 'top'
                  ? (hasBadgeOverlay
                      ? edgeInset + badgeRowH + (fullSize ? 8 : 3)
                      : edgeInset)
                  : null,
              bottom: textPosition == 'bottom' ? edgeInset : null,
              child: _captionText(caption, captionFontSize),
            ),

        if (priceTag.isNotEmpty || mrpTag.isNotEmpty)
          Positioned(
            top: edgeInset, right: edgeInset,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: badgePadH, vertical: badgePadV),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mrpTag.isNotEmpty)
                    Text('₹$mrpTag',
                        style: TextStyle(
                          color: const Color(0xFF5A3A00),
                          fontSize: priceFontSize * 0.75,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFFCC2200),
                          decorationThickness: 2,
                        )),
                  if (priceTag.isNotEmpty)
                    Text('₹$priceTag',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: priceFontSize,
                            fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),

        if (badgeData != null)
          Positioned(
            top: edgeInset, left: edgeInset,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: badgePadH, vertical: badgePadV),
              decoration: BoxDecoration(
                color: badgeData.$2,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4)],
              ),
              child: Text(badgeData.$1.replaceAll(' 🔥', ''),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3)),
            ),
          ),

        if (!fullSize)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ),
          ),
      ],
    );

    if (fullSize) return content;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: 80, height: 142, child: content),
    );
  }

  Widget _captionText(String text, double fontSize) => Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );

  Widget _buildImage() {
    // Text-only slide
    if (widget.path == kTextSlide) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
            child: Icon(Icons.text_fields_rounded,
                color: Colors.white24, size: 32)),
      );
    }

    // Before/After slide
    if (isBeforeAfterPath(widget.path)) {
      final parts = decodeBeforeAfter(widget.path);
      Widget half(String hp) => File(hp).existsSync()
          ? Image.file(File(hp),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity)
          : _placeholder();
      return Row(
        children: [
          Expanded(child: ClipRect(child: half(parts[0]))),
          Container(width: 1, color: Colors.white54),
          Expanded(child: ClipRect(child: half(parts[1]))),
        ],
      );
    }

    if (_isVideo) {
      if (_videoThumb != null) {
        return Image.memory(_videoThumb!, fit: BoxFit.cover);
      }
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_rounded,
                  color: AppColors.textSecondary, size: 28),
              const SizedBox(height: 6),
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final file = File(widget.path);
    if (!file.existsSync()) return _placeholder();
    // Blur bg + centered contain — matches export for all aspect ratios.
    // Portrait fills frame naturally; landscape shows blur sides.
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Image.file(file, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder()),
        ),
        Image.file(file, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox()),
      ],
    );
  }

  Widget _placeholder() => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0A4A), Color(0xFF12093A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_rounded,
            color: AppColors.textDisabled, size: 22)));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
    required this.onChanged,
    this.prefix,
    this.keyboardType,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String? prefix;
  final int maxLength;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: 1,
          keyboardType: keyboardType,
          style: AppTextStyles.bodySmall
              .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary),
            hintText: hint,
            hintStyle: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textDisabled, fontSize: 12),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            counterStyle: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textDisabled, fontSize: 9),
          ),
        ),
      );
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32, height: 32,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.bgElevated
                : AppColors.bgElevated.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? AppColors.divider : AppColors.divider.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textSecondary : AppColors.textDisabled,
          ),
        ),
      );
}

class _ApplyToAllLink extends StatelessWidget {
  const _ApplyToAllLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.copy_all_rounded,
                  size: 11, color: AppColors.primary),
              const SizedBox(width: 4),
              Text('Apply to all frames',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.divider.withValues(alpha: 0),
            AppColors.divider,
            AppColors.divider.withValues(alpha: 0),
          ]),
        ),
      );
}

// ── Fullscreen video preview (plays inside 9:16 dialog) ──────────────────────

class _FullscreenVideoPreview extends StatefulWidget {
  const _FullscreenVideoPreview({
    required this.path,
    required this.caption,
    required this.priceTag,
    required this.mrpTag,
    required this.offerBadge,
    required this.textPosition,
    required this.badgeSize,
  });
  final String path;
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;

  @override
  State<_FullscreenVideoPreview> createState() => _FullscreenVideoPreviewState();
}

class _FullscreenVideoPreviewState extends State<_FullscreenVideoPreview> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.path));
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      _ctrl.setLooping(true);
      _ctrl.play();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
      _showControls = !_ctrl.value.isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video layer (blur bg + contain fg for landscape) ──────
          if (_initialized) ...[
            // Blurred fill background for landscape videos
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl.value.size.width,
                  height: _ctrl.value.size.height,
                  child: VideoPlayer(_ctrl),
                ),
              ),
            ),
            // Sharp centered video
            Center(
              child: AspectRatio(
                aspectRatio: _ctrl.value.aspectRatio,
                child: VideoPlayer(_ctrl),
              ),
            ),
          ] else
            Container(color: Colors.black,
                child: const Center(child: CircularProgressIndicator())),

          // ── Caption overlays (same as _LiveThumbnail) ─────────────
          _OverlayLayer(
            caption: widget.caption,
            priceTag: widget.priceTag,
            mrpTag: widget.mrpTag,
            offerBadge: widget.offerBadge,
            textPosition: widget.textPosition,
            badgeSize: widget.badgeSize,
          ),

          // ── Play/pause indicator ──────────────────────────────────
          if (_initialized && (!_ctrl.value.isPlaying || _showControls))
            Center(
              child: AnimatedOpacity(
                opacity: _ctrl.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _ctrl.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white, size: 32,
                  ),
                ),
              ),
            ),

          // ── Progress bar at bottom ────────────────────────────────
          if (_initialized)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: VideoProgressIndicator(
                _ctrl,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.black38,
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
        ],
      ),
    );
  }
}

// Caption + badge overlay extracted so it's shared between image and video previews
class _OverlayLayer extends StatelessWidget {
  const _OverlayLayer({
    required this.caption,
    required this.priceTag,
    required this.mrpTag,
    required this.offerBadge,
    required this.textPosition,
    required this.badgeSize,
  });
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;

  @override
  Widget build(BuildContext context) {
    final badgeData = offerBadge.isNotEmpty
        ? _badges.where((b) => b.$1 == offerBadge).firstOrNull
        : null;

    const Map<String, double> sizeFactors = {
      'small': 0.65, 'medium': 1.0, 'large': 1.50,
    };
    final sf            = sizeFactors[badgeSize] ?? 1.0;
    const double edge   = 12.0;
    final badgeFontSize = 11.0 * sf;
    final priceFontSize = 12.0 * sf;
    final badgePadH     = 8.0 * sf;
    final badgePadV     = 4.0 * sf;
    final hasBadgeOverlay = priceTag.isNotEmpty || mrpTag.isNotEmpty || offerBadge.isNotEmpty;
    final badgeRowH     = badgeFontSize + badgePadV * 2 + 6;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient scrim
        if (caption.isNotEmpty)
          if (textPosition == 'center')
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(height: 120,
                    color: const Color(0x88000000)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: textPosition == 'top'
                      ? Alignment.bottomCenter : Alignment.topCenter,
                  end: textPosition == 'top'
                      ? Alignment.topCenter : Alignment.bottomCenter,
                  colors: const [Colors.transparent, Color(0xCC000000)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

        // Caption
        if (caption.isNotEmpty)
          if (textPosition == 'center')
            Positioned.fill(
              left: edge, right: edge,
              child: Center(child: _captionText(caption)),
            )
          else
            Positioned(
              left: edge, right: edge,
              top: textPosition == 'top'
                  ? (hasBadgeOverlay ? edge + badgeRowH + 8 : edge)
                  : null,
              bottom: textPosition == 'bottom' ? edge : null,
              child: _captionText(caption),
            ),

        // Price badge
        if (priceTag.isNotEmpty || mrpTag.isNotEmpty)
          Positioned(
            top: edge, right: edge,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: badgePadH, vertical: badgePadV),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mrpTag.isNotEmpty)
                    Text('₹$mrpTag',
                        style: TextStyle(
                          color: const Color(0xFF5A3A00),
                          fontSize: priceFontSize * 0.75,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFFCC2200),
                          decorationThickness: 2,
                        )),
                  if (priceTag.isNotEmpty)
                    Text('₹$priceTag',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: priceFontSize,
                            fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),

        // Offer badge
        if (badgeData != null)
          Positioned(
            top: edge, left: edge,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: badgePadH, vertical: badgePadV),
              decoration: BoxDecoration(
                color: badgeData.$2,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: Text(badgeData.$1,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3)),
            ),
          ),
      ],
    );
  }

  Widget _captionText(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: borderColor, width: isSelected ? 1.5 : 1),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: borderColor.withValues(alpha: 0.3),
                    blurRadius: 6)]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
              )),
        ),
      );
}
