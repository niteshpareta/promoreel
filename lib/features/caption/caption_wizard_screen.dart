import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/pr_section_header.dart';
import '../../core/ui/tokens.dart';
import '../../core/utils/text_position.dart';
import '../../data/models/video_project.dart';
import '../../data/services/background_removal_service.dart';
import '../../features/shared/widgets/no_project_fallback.dart';
import '../../providers/project_provider.dart';
import 'text_editor_sheet.dart';

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
  _Template(Icons.bolt_rounded,           'Flash Sale',  '50% OFF',    2, AppColors.signalCrimson),
  _Template(Icons.auto_awesome_rounded,   'New Arrival', 'NEW',        3, AppColors.signalLeaf),
  _Template(Icons.currency_rupee_rounded, 'Price Drop',  'SALE',       2, AppColors.brandEmber),
  _Template(Icons.campaign_rounded,       'Today Only',  'TODAY ONLY', 3, AppColors.signalSky),
  _Template(Icons.local_fire_department_rounded, 'Hot Deal', 'HOT',    2, Color(0xFFFF6E40)),
  _Template(Icons.celebration_rounded,   'Festival',    'LIMITED',     3, AppColors.proAurum),
];

// ── Badge options ─────────────────────────────────────────────────────────────

const _badges = [
  ('SALE',       AppColors.signalCrimson, Color(0xFF4A0F25)),
  ('NEW',        AppColors.signalLeaf,    Color(0xFF0E3E23)),
  ('HOT',        Color(0xFFFF6E40),       Color(0xFF3A1A08)),
  ('50% OFF',    AppColors.brandEmber,    Color(0xFF3D2307)),
  ('LIMITED',    AppColors.proAurum,      Color(0xFF3D2B00)),
  ('TODAY ONLY', AppColors.signalSky,     Color(0xFF0C2A4D)),
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

  /// Open the tap-to-edit bottom sheet for caption / price / MRP. The sheet
  /// returns `(text, applyToAll)` which we write through the provider, then
  /// mirror back into the local controllers so the preview rebuilds.
  Future<void> _openTextEditor({
    required int index,
    required PrTextEditorKind kind,
  }) async {
    final controller = switch (kind) {
      PrTextEditorKind.caption => _captionCtrls[index],
      PrTextEditorKind.price => _priceCtrls[index],
      PrTextEditorKind.mrp => _mrpCtrls[index],
    };

    final result = await showPrTextEditor(
      context,
      kind: kind,
      initialText: controller.text,
      frameIndex: index,
      totalFrames: _captionCtrls.length,
    );
    if (result == null || !mounted) return;

    final text = result.text;
    controller.text = text;
    final notifier = ref.read(projectProvider.notifier);

    void applyOne(int i) {
      switch (kind) {
        case PrTextEditorKind.caption:
          _captionCtrls[i].text = text;
          notifier.setFrameCaption(i, text);
          break;
        case PrTextEditorKind.price:
          _priceCtrls[i].text = text;
          notifier.setFramePriceTag(i, text);
          break;
        case PrTextEditorKind.mrp:
          _mrpCtrls[i].text = text;
          notifier.setFrameMrpTag(i, text);
          break;
      }
    }

    if (result.applyToAll) {
      for (var i = 0; i < _captionCtrls.length; i++) {
        applyOne(i);
      }
    } else {
      applyOne(index);
    }
    setState(() {});
  }

  void _showFullPreview({
    required String path,
    required String caption,
    required String priceTag,
    required String mrpTag,
    required String offerBadge,
    required String textPosition,
    required String badgeSize,
    bool bgRemoval = false,
    int bgColorArgb = 0,
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
                        bgRemoval: bgRemoval,
                        bgColorArgb: bgColorArgb,
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
    if (project == null) return const NoProjectFallback();

    final paths = project.assetPaths;
    final total = paths.length;
    if (_captionCtrls.length != total || _mrpCtrls.length != total) _initControllers();

    final customized = _customizedCount;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Top bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.xs, PrSpacing.xs, PrSpacing.lg, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(PrIcons.back),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: PrSectionHeader(
                      kicker: 'step 2 of 4',
                      title: 'Customize frames',
                      subtitle: customized == 0
                          ? 'Caption · price · badge · position'
                          : '$customized of $total customised',
                    ),
                  ),
                  TextButton(
                    onPressed: _done,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // ── Quick template strip ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  0, PrSpacing.md, 0, PrSpacing.xxs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: PrSpacing.lg, bottom: PrSpacing.xs),
                    child: Text('QUICK SETUP',
                        style: AppTextStyles.kicker),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: PrSpacing.md),
                      itemCount: _templates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: PrSpacing.xs + 2),
                      itemBuilder: (_, i) {
                        final t = _templates[i];
                        final active = _activeTemplate == t.label;
                        return GestureDetector(
                          onTap: () {
                            PrHaptics.select();
                            _applyTemplate(t);
                          },
                          child: AnimatedContainer(
                            duration: PrDuration.fast,
                            curve: PrCurves.enter,
                            width: 100,
                            padding: const EdgeInsets.symmetric(
                                horizontal: PrSpacing.sm, vertical: PrSpacing.xs + 2),
                            decoration: BoxDecoration(
                              color: active
                                  ? t.color.withValues(alpha: 0.14)
                                  : Theme.of(context).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(PrRadius.md),
                              border: Border.all(
                                color: active ? t.color : Theme.of(context).colorScheme.outlineVariant,
                                width: active ? 1.3 : 0.7,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(t.icon,
                                    size: 22,
                                    color: active ? t.color : Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(height: PrSpacing.xxs + 2),
                                Text(
                                  t.label,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: active ? t.color : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${t.duration}s',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
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
                    bgRemoval: project2.bgRemovalFor(i),
                    onBgRemovalToggle: () {
                      final enabled = project2.bgRemovalFor(i);
                      ref
                          .read(projectProvider.notifier)
                          .setFrameBgRemoval(i, !enabled);
                      setState(() {});
                    },
                    bgColor: project2.bgColorFor(i),
                    onBgColorChanged: (argb) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameBgColor(i, argb);
                      setState(() {});
                    },
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
                      bgRemoval: project2.bgRemovalFor(i),
                      bgColorArgb: project2.bgColorFor(i),
                    ),
                    onEditCaption: () => _openTextEditor(
                      index: i,
                      kind: PrTextEditorKind.caption,
                    ),
                    onEditPrice: () => _openTextEditor(
                      index: i,
                      kind: PrTextEditorKind.price,
                    ),
                  );
                },
              ),
            ),

            // ── Generate button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.md, PrSpacing.xxs, PrSpacing.md, PrSpacing.lg),
              child: PrButton(
                label: customized > 0
                    ? 'Continue · $customized customised'
                    : 'Continue',
                icon: PrIcons.sparkle,
                onPressed: _done,
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
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.md, PrSpacing.xxs, PrSpacing.md, PrSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: PrSpacing.xs),
            child: Text('TEXT ENTRANCE', style: AppTextStyles.kicker),
          ),
          Row(
            children: _options.map((opt) {
              final active = selected == opt.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    PrHaptics.select();
                    onSelected(opt.$1);
                  },
                  child: AnimatedContainer(
                    duration: PrDuration.fast,
                    curve: PrCurves.enter,
                    margin: EdgeInsets.only(
                        right: opt.$1 == 'slide_up' ? 0 : PrSpacing.xs),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.brandEmber.withValues(alpha: 0.12)
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(PrRadius.sm + 2),
                      border: Border.all(
                        color: active
                            ? AppColors.brandEmber
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: active ? 1.3 : 0.7,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(opt.$2,
                            size: 18,
                            color: active
                                ? AppColors.brandEmber
                                : Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 4),
                        Text(opt.$3,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
    required this.bgRemoval,
    required this.onBgRemovalToggle,
    required this.bgColor,
    required this.onBgColorChanged,
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
    this.onEditCaption,
    this.onEditPrice,
    this.onEditBadge,
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
  final bool bgRemoval;
  final VoidCallback onBgRemovalToggle;

  /// Current replacement background colour for this frame. `0` means
  /// "default" (render time treats it as brand ember).
  final int bgColor;
  final ValueChanged<int> onBgColorChanged;
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

  /// Fires when the user taps the caption region on the preview.
  /// Parent opens `showPrTextEditor(kind: caption)` and writes the result
  /// back via [onCaptionChanged] + optionally [onApplyToAll].
  final VoidCallback? onEditCaption;

  /// Fires when the user taps the price/MRP badge on the preview.
  final VoidCallback? onEditPrice;

  /// Fires when the user taps the offer badge on the preview — opens the
  /// existing badge picker (currently handled via chips below).
  final VoidCallback? onEditBadge;

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
                        bgRemoval: bgRemoval,
                        bgColorArgb: bgColor,
                        onCaptionTap: onEditCaption,
                        onPriceTap: onEditPrice,
                        onBadgeTap: onEditBadge,
                        onCaptionDrag: (offset) {
                          onPositionSelected(
                            TextPosition.fromOffsetWithPresetSnap(offset).raw,
                          );
                        },
                      ),
                      // Fullscreen chip — bottom-right corner, only now
                      // triggers fullscreen preview (not the whole surface)
                      if (onPreview != null)
                        Positioned(
                          bottom: 10, right: 10,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: onPreview,
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
                const SizedBox(height: 6),
                // Drag-to-position hint (replaces the 3-position picker —
                // the caption on the preview above is draggable).
                Row(
                  children: [
                    const Icon(Icons.drag_indicator_rounded,
                        size: 12, color: AppColors.textDisabled),
                    const SizedBox(width: 4),
                    Text(
                      textPosition.startsWith('custom:')
                          ? 'Drag the caption on the preview to reposition'
                          : 'Tap the preview to edit · drag the caption to position',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textDisabled,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
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
                const SizedBox(height: 14),

                // ── Clean background (subject segmentation) ───────────
                Row(
                  children: [
                    _SectionLabel(
                        Icons.auto_fix_high_rounded, 'Clean background'),
                    const Spacer(),
                    Switch.adaptive(
                      value: bgRemoval,
                      onChanged: (_) => onBgRemovalToggle(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bgRemoval
                      ? 'Subject is isolated and placed on the colour you pick below.'
                      : 'Turn on to auto-isolate the product from a messy background.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: bgRemoval
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _BgColorRow(
                            selected: bgColor,
                            onSelected: onBgColorChanged,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
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

// (Old _TextPositionPicker removed — caption position is now controlled
//  by direct drag on the preview, saved as 'custom:x,y' in frameTextPositions.)

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
    this.bgRemoval = false,
    this.bgColorArgb = 0,
    this.onCaptionTap,
    this.onPriceTap,
    this.onBadgeTap,
    this.onCaptionDrag,
    this.onCaptionDragEnd,
  });
  final String path;
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;
  final bool fullSize;

  /// When true, run subject segmentation on the asset and render the cut-out
  /// over [bgColorArgb] (or brand ember if 0). Result is cached by the
  /// service so toggles and colour switches only compute-once-per-combo.
  final bool bgRemoval;
  final int bgColorArgb;

  /// Tap-to-edit callbacks. Null (the default) keeps the thumbnail passive —
  /// used for the small preview cards where tap should open the fullscreen
  /// preview instead. In the big frame-card preview, these are wired to
  /// [showPrTextEditor] so users can edit text without scrolling to
  /// textfields below.
  final VoidCallback? onCaptionTap;
  final VoidCallback? onPriceTap;
  final VoidCallback? onBadgeTap;

  /// Drag callbacks for free-form caption positioning. When set, the caption
  /// region becomes pan-draggable; the receiver should write the new
  /// fractional Offset into `frameTextPositions` via
  /// `TextPosition.fromOffsetWithPresetSnap(o).raw`.
  final void Function(Offset fractional)? onCaptionDrag;
  final VoidCallback? onCaptionDragEnd;

  @override
  State<_LiveThumbnail> createState() => _LiveThumbnailState();
}

class _LiveThumbnailState extends State<_LiveThumbnail> {
  static const _videoExts = {'.mp4', '.mov', '.3gp', '.mkv', '.avi', '.webm'};

  Uint8List? _videoThumb;
  bool _loadingThumb = false;

  /// While the caption is being dragged, this holds the live fractional
  /// offset so we can render guides and the latest position without waiting
  /// for the parent to write back through setState.
  Offset? _liveDragOffset;

  /// Active snap guide during drag — drives the ember alignment lines.
  TextSnapGuide _snapGuide = const TextSnapGuide();

  // ── Real-time background removal state ────────────────────────────────
  /// Path to the subject-isolated PNG for the current (asset, colour) pair.
  /// `null` means "not processed yet" — fall back to the original image.
  String? _bgRemovedPath;

  /// True while the segmenter is running. Drives the spinner overlay.
  bool _processingBg = false;

  /// Increments on every trigger so stale results from earlier colour
  /// changes don't overwrite a newer one.
  int _bgRequestId = 0;

  bool get _isVideo {
    final idx = widget.path.lastIndexOf('.');
    if (idx < 0) return false;
    return _videoExts.contains(widget.path.substring(idx).toLowerCase());
  }

  bool get _isRegularImage =>
      !_isVideo &&
      widget.path != kTextSlide &&
      !isBeforeAfterPath(widget.path);

  @override
  void initState() {
    super.initState();
    if (_isVideo) _loadThumb();
    _maybeProcessBg();
  }

  @override
  void didUpdateWidget(_LiveThumbnail old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _videoThumb = null;
      _bgRemovedPath = null;
      if (_isVideo) _loadThumb();
    }
    if (old.path != widget.path ||
        old.bgRemoval != widget.bgRemoval ||
        old.bgColorArgb != widget.bgColorArgb) {
      _maybeProcessBg();
    }
  }

  /// Kick off subject segmentation if the toggle is on and the asset is a
  /// regular image. Results are cached by the service, so re-triggering for
  /// the same (path, colour) combo is effectively free.
  Future<void> _maybeProcessBg() async {
    if (!widget.bgRemoval) {
      if (_bgRemovedPath != null || _processingBg) {
        setState(() {
          _bgRemovedPath = null;
          _processingBg = false;
        });
      }
      return;
    }
    if (!_isRegularImage) return;

    final reqId = ++_bgRequestId;
    final bgArgb = widget.bgColorArgb == 0 ? 0xFFF2A848 : widget.bgColorArgb;
    setState(() => _processingBg = true);

    final result = await BackgroundRemovalService.processToPath(
      inputPath: widget.path,
      backgroundColorArgb: bgArgb,
    );

    if (!mounted || reqId != _bgRequestId) return;
    setState(() {
      _bgRemovedPath = result;
      _processingBg = false;
    });
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

    const sizeFactors = <String, double>{
      'small': 0.65, 'medium': 1.0, 'large': 1.50,
    };
    final sf = sizeFactors[badgeSize] ?? 1.0;

    final captionFontSize = fullSize ? 18.0 : 7.0;
    final badgeFontSize   = (fullSize ? 11.0 : 6.0) * sf;
    final priceFontSize   = (fullSize ? 12.0 : 7.0) * sf;
    final badgePadH       = (fullSize ? 8.0  : 4.0) * sf;
    final badgePadV       = (fullSize ? 4.0  : 2.0) * sf;
    final edgeInset       = fullSize ? 12.0 : 5.0;

    final pos = TextPosition.parse(textPosition);
    final activeOffset = _liveDragOffset ?? pos.offset;
    final isDragging = _liveDragOffset != null;
    final isInteractive = fullSize &&
        (widget.onCaptionTap != null ||
            widget.onPriceTap != null ||
            widget.onBadgeTap != null ||
            widget.onCaptionDrag != null);

    final Widget content = LayoutBuilder(builder: (ctx, box) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(),

          // Real-time bg-removal spinner overlay.
          if (_processingBg && widget.bgRemoval)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: fullSize ? 26 : 14,
                        height: fullSize ? 26 : 14,
                        child: CircularProgressIndicator(
                          strokeWidth: fullSize ? 2.5 : 1.5,
                          color: AppColors.brandEmber,
                        ),
                      ),
                      if (fullSize) ...[
                        const SizedBox(height: 10),
                        Text('Isolating subject…',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Subtle scrim only for legacy presets (top/center/bottom).
          // Custom-positioned captions rely on the text's own drop shadow.
          if (caption.isNotEmpty && !pos.isCustom && !isDragging)
            _buildLegacyScrim(textPosition, fullSize),

          // Caption — positioned by fractional Offset, pan-draggable in
          // fullSize mode when onCaptionDrag is wired.
          if (caption.isNotEmpty)
            _buildCaption(
              caption: caption,
              fontSize: captionFontSize,
              offset: activeOffset,
              boxSize: Size(box.maxWidth, box.maxHeight),
              edgeInset: edgeInset,
              draggable: isInteractive && widget.onCaptionDrag != null,
              tappable: isInteractive && widget.onCaptionTap != null,
            ),

          // Snap guides during drag — thin ember alignment lines.
          if (isDragging && _snapGuide.hasSnap)
            Positioned.fill(
              child: IgnorePointer(child: _SnapGuideOverlay(guide: _snapGuide)),
            ),

          // Price / MRP badge — top-right, tappable.
          if (priceTag.isNotEmpty || mrpTag.isNotEmpty)
            Positioned(
              top: edgeInset, right: edgeInset,
              child: _tapShell(
                enabled: isInteractive && widget.onPriceTap != null,
                onTap: widget.onPriceTap,
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
            ),

          if (badgeData != null)
            Positioned(
              top: edgeInset, left: edgeInset,
              child: _tapShell(
                enabled: isInteractive && widget.onBadgeTap != null,
                onTap: widget.onBadgeTap,
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
            ),

          // Empty-state "Tap to add caption" affordance — tappable so users
          // who haven't typed anything yet can still open the editor.
          // Shows whenever caption is empty (regardless of other fields).
          if (fullSize && caption.isEmpty && widget.onCaptionTap != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: edgeInset + 4,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      PrHaptics.tap();
                      widget.onCaptionTap!();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.brandEmber.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: AppColors.brandEmber, size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            'Tap to add caption',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
    });

    if (fullSize) return content;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: 80, height: 142, child: content),
    );
  }

  // ── Tap shell — wraps a widget with an InkWell when [enabled] is true. ──
  Widget _tapShell({
    required bool enabled,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    if (!enabled || onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          PrHaptics.tap();
          onTap();
        },
        child: child,
      ),
    );
  }

  // ── Legacy scrim (top/center/bottom gradient band) ──────────────────────
  Widget _buildLegacyScrim(String textPosition, bool fullSize) {
    if (textPosition == 'center') {
      return Positioned.fill(
        child: Align(
          alignment: Alignment.center,
          child: Container(
            height: fullSize ? 120 : 40,
            decoration: const BoxDecoration(color: Color(0x88000000)),
          ),
        ),
      );
    }
    return Container(
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
    );
  }

  // ── Caption rendered at fractional offset with gestures ─────────────────
  //
  // Gestures use long-press-drag (not pan) so the drag recogniser wins the
  // gesture arena against the enclosing ListView's vertical scroll. Tap
  // fires instantly via `onTap`; drag requires a ~250 ms hold to start,
  // signalled by a haptic pulse + ember ring around the caption.
  //
  // The GestureDetector wraps ONLY the text widget (not a full-size Align),
  // so tapping empty areas of the frame doesn't accidentally move the
  // caption; empty taps fall through to the empty-state hint underneath.
  Widget _buildCaption({
    required String caption,
    required double fontSize,
    required Offset offset,
    required Size boxSize,
    required double edgeInset,
    required bool draggable,
    required bool tappable,
  }) {
    final maxCapWidth =
        (boxSize.width - edgeInset * 2).clamp(32.0, double.infinity);

    Widget captionText = Text(
      caption,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 12, offset: Offset(1, 1)),
          Shadow(color: Colors.black, blurRadius: 6),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    // Add inner padding so the gesture hit box extends slightly beyond the
    // glyphs themselves — easier to grab on thin text.
    Widget captionBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: _liveDragOffset != null
          ? BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: AppColors.brandEmber,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxCapWidth),
        child: captionText,
      ),
    );

    if (tappable || draggable) {
      captionBox = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable
            ? () {
                PrHaptics.tap();
                widget.onCaptionTap?.call();
              }
            : null,
        // Long-press-drag — wins the arena over the parent ListView scroll.
        onLongPressStart: draggable
            ? (_) {
                PrHaptics.select();
                setState(() {
                  _liveDragOffset = offset;
                  _snapGuide = const TextSnapGuide();
                });
              }
            : null,
        onLongPressMoveUpdate: draggable
            ? (d) {
                // `offsetFromOrigin` is the total drag since long-press start.
                final base = offset;
                final dx = d.offsetFromOrigin.dx / boxSize.width;
                final dy = d.offsetFromOrigin.dy / boxSize.height;
                final raw = Offset(
                  (base.dx + dx).clamp(0.05, 0.95),
                  (base.dy + dy).clamp(0.05, 0.95),
                );
                final guide = applyDragSnap(raw);
                final snapped = snapOffset(raw, guide);
                setState(() {
                  _liveDragOffset = snapped;
                  _snapGuide = guide;
                });
                widget.onCaptionDrag?.call(snapped);
              }
            : null,
        onLongPressEnd: draggable
            ? (_) {
                widget.onCaptionDragEnd?.call();
                setState(() {
                  _liveDragOffset = null;
                  _snapGuide = const TextSnapGuide();
                });
              }
            : null,
        child: captionBox,
      );
    }

    return Align(
      alignment: Alignment(offset.dx * 2 - 1, offset.dy * 2 - 1),
      child: captionBox,
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
    // Subject-isolated cutout takes precedence when available — this is
    // the real-time preview of the "Clean background" feature.
    if (widget.bgRemoval &&
        _bgRemovedPath != null &&
        File(_bgRemovedPath!).existsSync()) {
      return Image.file(
        File(_bgRemovedPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Snap-guide overlay — thin ember lines shown while dragging the caption.
// ─────────────────────────────────────────────────────────────────────────────

class _SnapGuideOverlay extends StatelessWidget {
  const _SnapGuideOverlay({required this.guide});
  final TextSnapGuide guide;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SnapGuidePainter(guide));
  }
}

class _SnapGuidePainter extends CustomPainter {
  _SnapGuidePainter(this.guide);
  final TextSnapGuide guide;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandEmber.withValues(alpha: 0.85)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    if (guide.snappedX != null) {
      final x = size.width * guide.snappedX!;
      _dashedLine(canvas,
          Offset(x, 8), Offset(x, size.height - 8), paint, dash: 5, gap: 4);
    }
    if (guide.snappedY != null) {
      final y = size.height * guide.snappedY!;
      _dashedLine(canvas,
          Offset(8, y), Offset(size.width - 8, y), paint, dash: 5, gap: 4);
    }
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final delta = b - a;
    final len = delta.distance;
    final dir = delta / len;
    double travelled = 0;
    while (travelled < len) {
      final start = a + dir * travelled;
      final end = a + dir * (travelled + dash).clamp(0, len);
      canvas.drawLine(start, end, paint);
      travelled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SnapGuidePainter old) =>
      old.guide.snappedX != guide.snappedX ||
      old.guide.snappedY != guide.snappedY;
}

// ─────────────────────────────────────────────────────────────────────────────
// Background colour picker — a small curated palette for the "clean
// background" feature. Each swatch writes an ARGB int via [onSelected]; the
// special value 0 means "Default" (render time resolves to brand ember).
//
// The palette is deliberately narrow so users don't stall picking — these
// are the seven colours that actually read well behind a cut-out subject
// across retail / service / creator use cases.
// ─────────────────────────────────────────────────────────────────────────────

class _BgColorRow extends StatelessWidget {
  const _BgColorRow({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  /// (displayArgb, storedArgb, label). `storedArgb = 0` is the sentinel
  /// "Default" that the renderer maps to ember.
  static const List<(int, int, String)> _swatches = [
    (0xFFF2A848, 0,          'Ember'),   // default
    (0xFFFFFFFF, 0xFFFFFFFF, 'White'),
    (0xFFF7F3ED, 0xFFF7F3ED, 'Cream'),
    (0xFF141110, 0xFF141110, 'Noir'),
    (0xFFCFE8FF, 0xFFCFE8FF, 'Sky'),
    (0xFFBDF5DC, 0xFFBDF5DC, 'Mint'),
    (0xFFFEC9C9, 0xFFFEC9C9, 'Blush'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _swatches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (display, stored, label) = _swatches[i];
          final isSelected = selected == stored;
          return _SwatchChip(
            displayColor: Color(display),
            label: label,
            isSelected: isSelected,
            onTap: () => onSelected(stored),
          );
        },
      ),
    );
  }
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({
    required this.displayColor,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Color displayColor;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        PrHaptics.select();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: displayColor,
              border: Border.all(
                color: isSelected
                    ? AppColors.brandEmber
                    : Colors.black.withValues(alpha: 0.12),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.brandEmber.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: displayColor.computeLuminance() > 0.55
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected
                  ? AppColors.brandEmber
                  : scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
