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
import '../../data/models/badge_style.dart';
import '../../data/models/caption_style.dart';
import '../../data/models/video_project.dart';
import '../../engine/badge_painter.dart';
import '../../engine/text_renderer.dart' show googleFontsStyleFor;
import '../../data/services/background_removal_service.dart';
import '../../features/shared/widgets/no_project_fallback.dart';
import '../../providers/project_provider.dart';
import 'text_editor_sheet.dart';

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

    final project = ref.read(projectProvider);
    final result = await showPrTextEditor(
      context,
      kind: kind,
      initialText: controller.text,
      frameIndex: index,
      totalFrames: _captionCtrls.length,
      initialCaptionStyleId: project?.captionStyleIdFor(index)
          ?? CaptionStyle.defaultStyleId,
      onCaptionStyleChanged: (styleId) {
        // Style edits commit immediately — independent of Apply/Cancel on
        // the text. Matches Canva's "style sticks as you browse presets"
        // behaviour.
        ref.read(projectProvider.notifier).setFrameCaptionStyle(index, styleId);
        setState(() {});
      },
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
    String captionStyleId = CaptionStyle.defaultStyleId,
    CaptionStyle? captionStyleResolved,
    BadgeStyle? badgeStyleResolved,
    String badgeAnimStyle = 'none',
    bool captionUppercase = false,
    int captionRotation = 0,
    bool bgRemoval = false,
    int bgColorArgb = 0,
  }) {
    final animStyle = ref.read(projectProvider)?.textAnimStyle ?? 'none';
    final isVideo = _isVideoPath(path);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => _FullPreviewDialog(
        path: path,
        caption: caption,
        priceTag: priceTag,
        mrpTag: mrpTag,
        offerBadge: offerBadge,
        textPosition: textPosition,
        badgeSize: badgeSize,
        captionStyle: captionStyleResolved ?? CaptionStyle.byId(captionStyleId),
        captionStyleId: captionStyleId,
        captionUppercase: captionUppercase,
        captionRotation: captionRotation,
        animStyle: animStyle,
        badgeStyle: badgeStyleResolved ?? BadgeStyle.defaultStyle,
        badgeAnimStyle: badgeAnimStyle,
        bgRemoval: bgRemoval,
        bgColorArgb: bgColorArgb,
        isVideo: isVideo,
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

            // Text-entrance anim is now picked per-frame via the Motion
            // button in each frame's caption toolbar — the legacy
            // `_TextAnimStylePicker` here only exposed 3 options (none /
            // fade / slide_up) and silently overrode the richer choices
            // (typewriter / wipe / pop) picked from the Motion sheet.

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
                    captionStyleId: project2.captionStyleIdFor(i),
                    captionStyleResolved: project2.resolvedCaptionStyleFor(i),
                    captionUppercase: project2.captionUppercaseFor(i),
                    captionRotation: project2.captionRotationFor(i),
                    captionAnimStyle: project2.textAnimStyle,
                    badgeStyleId: project2.offerBadgeStyleIdFor(i),
                    badgeStyleResolved: project2.resolvedOfferBadgeStyleFor(i),
                    badgeAnimStyle: project2.offerBadgeAnimFor(i),
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
                    onCaptionStyleSelected: (styleId) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionStyle(i, styleId);
                      setState(() {});
                    },
                    onCaptionFontSelected: (family) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionFont(i, family);
                      setState(() {});
                    },
                    onCaptionTextColorSelected: (argb) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionTextColor(i, argb);
                      setState(() {});
                    },
                    onCaptionPillColorSelected: (argb) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionPillColor(i, argb);
                      setState(() {});
                    },
                    onCaptionEffectSelected: (effect) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionEffect(i, effect);
                      setState(() {});
                    },
                    onCaptionUppercaseToggled: (value) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionUppercase(i, value);
                      setState(() {});
                    },
                    onCaptionMotionSelected: (style) {
                      ref
                          .read(projectProvider.notifier)
                          .setTextAnimStyle(style);
                      setState(() {});
                    },
                    onCaptionRotationChanged: (deg) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameCaptionRotation(i, deg);
                      setState(() {});
                    },
                    onBadgeStyleSelected: (styleId) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameOfferBadgeStyle(i, styleId);
                      setState(() {});
                    },
                    onBadgeFillColorSelected: (argb) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameOfferBadgeFillColor(i, argb);
                      setState(() {});
                    },
                    onBadgeTextColorSelected: (argb) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameOfferBadgeTextColor(i, argb);
                      setState(() {});
                    },
                    onBadgeAnimSelected: (anim) {
                      ref
                          .read(projectProvider.notifier)
                          .setFrameOfferBadgeAnim(i, anim);
                      setState(() {});
                    },
                    onApplyBadgeToAll: total > 1
                        ? () {
                            PrHaptics.commit();
                            ref
                                .read(projectProvider.notifier)
                                .applyBadgeToAll(i);
                            setState(() {});
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  backgroundColor:
                                      AppColors.brandEmber.withValues(alpha: 0.95),
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Badge applied to all frames',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              );
                          }
                        : null,
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
                      captionStyleId: project2.captionStyleIdFor(i),
                      captionStyleResolved: project2.resolvedCaptionStyleFor(i),
                      captionUppercase: project2.captionUppercaseFor(i),
                      captionRotation: project2.captionRotationFor(i),
                      badgeStyleResolved: project2.resolvedOfferBadgeStyleFor(i),
                      badgeAnimStyle: project2.offerBadgeAnimFor(i),
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

class _FrameCard extends StatefulWidget {
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
    required this.captionStyleId,
    required this.captionStyleResolved,
    required this.captionUppercase,
    required this.captionRotation,
    required this.captionAnimStyle,
    required this.badgeStyleId,
    required this.badgeStyleResolved,
    required this.badgeAnimStyle,
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
    required this.onCaptionStyleSelected,
    required this.onCaptionFontSelected,
    required this.onCaptionTextColorSelected,
    required this.onCaptionPillColorSelected,
    required this.onCaptionEffectSelected,
    required this.onCaptionUppercaseToggled,
    required this.onCaptionMotionSelected,
    required this.onCaptionRotationChanged,
    required this.onBadgeStyleSelected,
    required this.onBadgeFillColorSelected,
    required this.onBadgeTextColorSelected,
    required this.onBadgeAnimSelected,
    required this.onApplyBadgeToAll,
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
  final String captionStyleId;
  final CaptionStyle captionStyleResolved;
  final bool captionUppercase;
  final int captionRotation;
  final String captionAnimStyle;
  final String badgeStyleId;
  final BadgeStyle badgeStyleResolved;
  final String badgeAnimStyle;
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
  final ValueChanged<String> onCaptionStyleSelected;
  final ValueChanged<String> onCaptionFontSelected;
  final ValueChanged<int> onCaptionTextColorSelected;
  final ValueChanged<int> onCaptionPillColorSelected;
  final ValueChanged<String> onCaptionEffectSelected;
  final ValueChanged<bool> onCaptionUppercaseToggled;
  final ValueChanged<String> onCaptionMotionSelected;
  final ValueChanged<int> onCaptionRotationChanged;
  final ValueChanged<String> onBadgeStyleSelected;
  final ValueChanged<int> onBadgeFillColorSelected;
  final ValueChanged<int> onBadgeTextColorSelected;
  final ValueChanged<String> onBadgeAnimSelected;
  final VoidCallback? onApplyBadgeToAll;
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

  @override
  State<_FrameCard> createState() => _FrameCardState();
}

class _FrameCardState extends State<_FrameCard> {
  /// Incremented on each ▶ tap so `_LiveThumbnail.didUpdateWidget` can
  /// detect the change and re-run the entrance animation.
  int _replayTick = 0;

  bool get _hasAny =>
      widget.captionCtrl.text.isNotEmpty ||
      widget.priceCtrl.text.isNotEmpty ||
      widget.mrpCtrl.text.isNotEmpty ||
      widget.offerBadge.isNotEmpty;

  // Savings chip data
  String? get _savingsText {
    final mrp = double.tryParse(widget.mrpCtrl.text.trim());
    final offer = double.tryParse(widget.priceCtrl.text.trim());
    if (mrp == null || offer == null || mrp <= offer) return null;
    final saved = (mrp - offer).round();
    final pct = ((mrp - offer) / mrp * 100).round();
    return 'You save ₹$saved ($pct% off)';
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final total = widget.total;
    final path = widget.path;
    final captionCtrl = widget.captionCtrl;
    final priceCtrl = widget.priceCtrl;
    final mrpCtrl = widget.mrpCtrl;
    final captionFocus = widget.captionFocus;
    final priceFocus = widget.priceFocus;
    final mrpFocus = widget.mrpFocus;
    final mrpTag = widget.mrpTag;
    final offerBadge = widget.offerBadge;
    final badgeSize = widget.badgeSize;
    final duration = widget.duration;
    final textPosition = widget.textPosition;
    final captionStyleId = widget.captionStyleId;
    final captionStyleResolved = widget.captionStyleResolved;
    final captionUppercase = widget.captionUppercase;
    final captionRotation = widget.captionRotation;
    final captionAnimStyle = widget.captionAnimStyle;
    final bgRemoval = widget.bgRemoval;
    final onBgRemovalToggle = widget.onBgRemovalToggle;
    final bgColor = widget.bgColor;
    final onBgColorChanged = widget.onBgColorChanged;
    final onCaptionChanged = widget.onCaptionChanged;
    final onPriceChanged = widget.onPriceChanged;
    final onMrpChanged = widget.onMrpChanged;
    final onBadgeSelected = widget.onBadgeSelected;
    final onBadgeSizeSelected = widget.onBadgeSizeSelected;
    final onDurationSelected = widget.onDurationSelected;
    final onPositionSelected = widget.onPositionSelected;
    final onCaptionStyleSelected = widget.onCaptionStyleSelected;
    final onCaptionFontSelected = widget.onCaptionFontSelected;
    final onCaptionTextColorSelected = widget.onCaptionTextColorSelected;
    final onCaptionPillColorSelected = widget.onCaptionPillColorSelected;
    final onCaptionEffectSelected = widget.onCaptionEffectSelected;
    final onCaptionUppercaseToggled = widget.onCaptionUppercaseToggled;
    final onCaptionMotionSelected = widget.onCaptionMotionSelected;
    final onCaptionRotationChanged = widget.onCaptionRotationChanged;
    final onBadgeStyleSelected = widget.onBadgeStyleSelected;
    final onBadgeFillColorSelected = widget.onBadgeFillColorSelected;
    final onBadgeTextColorSelected = widget.onBadgeTextColorSelected;
    final onBadgeAnimSelected = widget.onBadgeAnimSelected;
    final onApplyBadgeToAll = widget.onApplyBadgeToAll;
    final badgeStyleId = widget.badgeStyleId;
    final badgeStyleResolved = widget.badgeStyleResolved;
    final badgeAnimStyle = widget.badgeAnimStyle;
    final onMoveUp = widget.onMoveUp;
    final onMoveDown = widget.onMoveDown;
    final onRemove = widget.onRemove;
    final onApplyToAll = widget.onApplyToAll;
    final onPreview = widget.onPreview;
    final onEditCaption = widget.onEditCaption;
    final onEditPrice = widget.onEditPrice;
    final onEditBadge = widget.onEditBadge;
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
                        captionStyleId: captionStyleId,
                        captionStyleOverride: captionStyleResolved,
                        uppercase: captionUppercase,
                        rotationDegrees: captionRotation,
                        animStyle: captionAnimStyle,
                        replayTick: _replayTick,
                        badgeStyle: badgeStyleResolved,
                        badgeAnimStyle: badgeAnimStyle,
                        fullSize: true,
                        bgRemoval: bgRemoval,
                        bgColorArgb: bgColor,
                        onCaptionTap: onEditCaption,
                        onPriceTap: onEditPrice,
                        onBadgeTap: onEditBadge,
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
                      // ▶ Play chip — bottom-left. Replays the entrance
                      // animation in real time inside the inline preview.
                      if (captionCtrl.text.isNotEmpty &&
                          captionAnimStyle != 'none')
                        Positioned(
                          bottom: 10, left: 10,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                PrHaptics.tap();
                                setState(() => _replayTick++);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brandEmber
                                      .withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Play',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800)),
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
                const SizedBox(height: 10),
                _CaptionPositionPicker(
                  selected: textPosition,
                  onSelected: onPositionSelected,
                ),
                const SizedBox(height: 10),
                _CaptionStyleToolbar(
                  resolvedStyle: captionStyleResolved,
                  styleId: captionStyleId,
                  uppercase: captionUppercase,
                  rotationDegrees: captionRotation,
                  animStyle: captionAnimStyle,
                  sampleText: captionCtrl.text.trim().isEmpty
                      ? 'Caption'
                      : captionCtrl.text.trim(),
                  onStylePicked: onCaptionStyleSelected,
                  onFontPicked: onCaptionFontSelected,
                  onTextColorPicked: onCaptionTextColorSelected,
                  onPillColorPicked: onCaptionPillColorSelected,
                  onEffectPicked: onCaptionEffectSelected,
                  onUppercaseToggled: onCaptionUppercaseToggled,
                  onMotionPicked: onCaptionMotionSelected,
                  onRotationChanged: onCaptionRotationChanged,
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
                // Free-form text field (any label the user types), plus a
                // quick-chip row for common choices. The style is
                // controlled separately via the Badge Style row below.
                _BadgeTextField(
                  text: offerBadge,
                  onChanged: onBadgeSelected,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in const [
                      'SALE', 'NEW', 'HOT', '50% OFF', 'LIMITED', 'TODAY ONLY'
                    ])
                      _QuickBadgeChip(
                        label: label,
                        selected: offerBadge == label,
                        onTap: () =>
                            onBadgeSelected(offerBadge == label ? '' : label),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _BadgeStyleToolbar(
                  styleId: badgeStyleId,
                  resolvedStyle: badgeStyleResolved,
                  animStyle: badgeAnimStyle,
                  sampleText: offerBadge.isEmpty ? 'SALE' : offerBadge,
                  onStylePicked: onBadgeStyleSelected,
                  onFillColorPicked: onBadgeFillColorSelected,
                  onTextColorPicked: onBadgeTextColorSelected,
                  onAnimPicked: onBadgeAnimSelected,
                ),
                if (offerBadge.isNotEmpty && onApplyBadgeToAll != null) ...[
                  const SizedBox(height: 6),
                  _ApplyToAllLink(onTap: onApplyBadgeToAll),
                ],

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
    this.captionStyleId = CaptionStyle.defaultStyleId,
    this.captionStyleOverride,
    this.uppercase = false,
    this.rotationDegrees = 0,
    this.animStyle = 'none',
    this.replayTick = 0,
    this.badgeStyle,
    this.badgeAnimStyle = 'none',
    this.fullSize = false,
    this.bgRemoval = false,
    this.bgColorArgb = 0,
    this.onCaptionTap,
    this.onPriceTap,
    this.onBadgeTap,
  });
  final String path;
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;
  final String captionStyleId;

  /// Optional already-resolved style (preset + overrides applied). When
  /// non-null this short-circuits the preset lookup — callers that have a
  /// fully resolved style from `VideoProject.resolvedCaptionStyleFor` can
  /// pass it straight through, ensuring preview matches export.
  final CaptionStyle? captionStyleOverride;

  /// Per-frame uppercase toggle — transforms the displayed caption to all
  /// caps without mutating the stored text.
  final bool uppercase;

  /// Per-frame caption rotation in degrees (−15 to 15). Applied as a
  /// `Transform.rotate` around the caption's own centre so the pill and
  /// text tilt together; position on the frame stays put.
  final int rotationDegrees;

  /// Project-level entrance animation (`none`/`fade`/`slide_up`/
  /// `typewriter`/`wipe`/`pop`). Used by the replay button on the inline
  /// preview to run the real-time animation in Flutter.
  final String animStyle;

  /// Incremented by the parent (`_FrameCard`) each time the user taps the
  /// ▶ replay chip. When the value changes, `didUpdateWidget` kicks off a
  /// fresh play of [animStyle].
  final int replayTick;

  /// Resolved per-frame badge style (preset + colour overrides). When
  /// null, the default style's look is used.
  final BadgeStyle? badgeStyle;

  /// Badge entrance animation — `'none'` / `'pop'` / `'slide_in'` /
  /// `'rotate_in'` / `'pulse'`. Plays as the caption entrance replays.
  final String badgeAnimStyle;
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

  @override
  State<_LiveThumbnail> createState() => _LiveThumbnailState();
}

class _LiveThumbnailState extends State<_LiveThumbnail>
    with SingleTickerProviderStateMixin {
  static const _videoExts = {'.mp4', '.mov', '.3gp', '.mkv', '.avi', '.webm'};

  Uint8List? _videoThumb;
  bool _loadingThumb = false;

  /// Drives the entrance-animation replay triggered by the ▶ chip. 0 → 1
  /// during play; otherwise sits at 1 so the caption is shown normally.
  AnimationController? _entranceCtrl;
  bool get _isReplaying =>
      (_entranceCtrl?.isAnimating ?? false) ||
      ((_entranceCtrl?.value ?? 1) < 1);

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
    _entranceCtrl = AnimationController(
      vsync: this,
      // Max duration across the supported anims (typewriter is the longest).
      duration: const Duration(milliseconds: 900),
    )
      ..addListener(() => setState(() {}))
      ..value = 1.0;
  }

  @override
  void dispose() {
    _entranceCtrl?.dispose();
    super.dispose();
  }

  /// Kick off a one-shot replay of the entrance animation. Called by the
  /// ▶ chip on the inline preview. The controller's value drives the
  /// caption's opacity / translation / scale / clip width — the math
  /// mirrors what the FFmpeg filter applies at export time.
  void _replayEntrance() {
    final c = _entranceCtrl;
    if (c == null) return;
    c.duration = _entranceDuration(widget.animStyle);
    c
      ..value = 0.0
      ..forward();
  }

  Duration _entranceDuration(String style) {
    switch (style) {
      case 'fade':
      case 'slide_up':
        return const Duration(milliseconds: 350);
      case 'pop':
        return const Duration(milliseconds: 300);
      case 'wipe':
        return const Duration(milliseconds: 350);
      case 'typewriter':
        return const Duration(milliseconds: 800);
      default:
        return const Duration(milliseconds: 300);
    }
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
    if (old.replayTick != widget.replayTick) {
      _replayEntrance();
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
    final isInteractive = fullSize &&
        (widget.onCaptionTap != null ||
            widget.onPriceTap != null ||
            widget.onBadgeTap != null);

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

          // Canva-style caption: no full-frame scrim; a pill hugging the
          // text plus the text's drop shadow handles legibility.

          // Caption at the selected preset (top / center / bottom).
          if (caption.isNotEmpty)
            _buildCaption(
              caption: widget.uppercase ? caption.toUpperCase() : caption,
              style: widget.captionStyleOverride ??
                  CaptionStyle.byId(widget.captionStyleId),
              fontSize: captionFontSize,
              offset: pos.offset,
              boxSize: Size(box.maxWidth, box.maxHeight),
              edgeInset: edgeInset,
              rotationDegrees: widget.rotationDegrees,
              // During replay, `progress < 1` — _applyEntrance below uses it
              // to drive opacity / slide / scale / clip.
              entranceProgress: _entranceCtrl?.value ?? 1.0,
              tappable: isInteractive && widget.onCaptionTap != null,
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

          // Offer badge — top-left. Uses the shared StyledBadge so its
          // shape + colours + decor match what the renderer exports.
          // Entrance animation rides the same controller as the caption so
          // Play/Replay animates both together.
          if (offerBadge.isNotEmpty)
            Positioned(
              top: edgeInset,
              left: edgeInset,
              child: _tapShell(
                enabled: isInteractive && widget.onBadgeTap != null,
                onTap: widget.onBadgeTap,
                child: _applyBadgeEntrance(
                  animStyle: widget.badgeAnimStyle,
                  progress: _entranceCtrl?.value ?? 1.0,
                  child: StyledBadge(
                    style: (widget.badgeStyle ?? BadgeStyle.defaultStyle),
                    text: offerBadge.replaceAll(' 🔥', ''),
                    fontSize: badgeFontSize,
                  ),
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

  // Caption painted at the chosen preset offset; tapping opens the editor.
  // [style] provides the font / colour / pill / effect selected in the
  // Style sub-sheet; `googleFontsStyleFor` matches the one the renderer
  // uses, so preview and export stay pixel-aligned.
  Widget _buildCaption({
    required String caption,
    required CaptionStyle style,
    required double fontSize,
    required Offset offset,
    required Size boxSize,
    required double edgeInset,
    required int rotationDegrees,
    required double entranceProgress,
    required bool tappable,
  }) {
    final maxCapWidth =
        (boxSize.width - edgeInset * 2).clamp(32.0, double.infinity);

    // Pill scales with the caption font so it looks right in both the
    // small-card preview (fontSize ~7) and the full-size preview (~18).
    final double padH = fontSize * 0.75;
    final double padV = fontSize * 0.35;
    final double radius = fontSize * 0.7;

    final textWidget = Text(
      caption,
      style: googleFontsStyleFor(style, fontSize: fontSize),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    Widget captionBox = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxCapWidth),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: style.pillColor != null
              ? BoxDecoration(
                  color: style.pillColor,
                  borderRadius: BorderRadius.circular(radius),
                )
              : null,
          child: textWidget,
        ),
      ),
    );

    if (tappable) {
      captionBox = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          PrHaptics.tap();
          widget.onCaptionTap?.call();
        },
        child: captionBox,
      );
    }

    if (rotationDegrees != 0) {
      captionBox = Transform.rotate(
        angle: rotationDegrees * 3.14159265358979 / 180.0,
        child: captionBox,
      );
    }

    // Entrance replay — mirrors the FFmpeg filter mathematically.
    captionBox = _applyEntrance(
      child: captionBox,
      caption: caption,
      style: style,
      fontSize: fontSize,
      progress: entranceProgress,
    );

    return Align(
      alignment: Alignment(offset.dx * 2 - 1, offset.dy * 2 - 1),
      child: captionBox,
    );
  }

  /// Apply the active entrance-animation transform to [child] for the given
  /// [progress] (0 = first frame, 1 = settled final pose). Matches the
  /// export-time math in `motion_style_engine.dart` and what TextRenderer
  /// hands to FFmpeg.
  Widget _applyEntrance({
    required Widget child,
    required String caption,
    required CaptionStyle style,
    required double fontSize,
    required double progress,
  }) {
    // Fully settled — no wrapper cost.
    if (progress >= 1.0) return child;
    final anim = widget.animStyle;
    switch (anim) {
      case 'fade':
        return Opacity(opacity: progress.clamp(0, 1), child: child);
      case 'slide_up':
        final dy = (1 - progress) * (fontSize * 4);
        return Transform.translate(offset: Offset(0, dy), child: child);
      case 'pop':
        final s = (0.6 + 0.4 * progress).clamp(0.6, 1.0);
        return Transform.scale(scale: s, child: child);
      case 'typewriter':
      case 'wipe':
        // Mirrors the FFmpeg filter's overlay-x slide from off-screen left.
        // We don't have the inline preview's full width here, so we use a
        // generous translate that shifts the caption block ~300px (well
        // past its own width for the small-card preview). At progress=1
        // the offset becomes 0 so the caption settles in-place.
        final dx = (1 - progress) * -300.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      default:
        return child;
    }
  }

  /// Entrance wrapper for the offer badge. Different defaults than the
  /// caption's: badges usually "pop" in, so we treat that as the default.
  Widget _applyBadgeEntrance({
    required Widget child,
    required String animStyle,
    required double progress,
  }) {
    if (progress >= 1.0) return child;
    switch (animStyle) {
      case 'pop':
        final s = (0.5 + 0.5 * progress).clamp(0.5, 1.0);
        return Transform.scale(scale: s, child: child);
      case 'slide_in':
        // From the left edge into position.
        final dx = (1 - progress) * -120.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      case 'rotate_in':
        final angle = (1 - progress) * 0.7; // ~40° over the whole anim
        final s = (0.6 + 0.4 * progress).clamp(0.6, 1.0);
        return Transform.rotate(
          angle: -angle,
          child: Transform.scale(scale: s, child: child),
        );
      case 'pulse':
        // Peaks at mid-progress (1.2×) then settles to 1.0.
        final peak = 1 - (progress * 2 - 1).abs();
        return Transform.scale(
          scale: (1.0 + 0.2 * peak).clamp(1.0, 1.2),
          child: child,
        );
      default:
        return child;
    }
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

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen preview dialog — wraps the 9:16 image/video body, the close
// chip, and (when the project has an entrance animation) a ▶ Play chip
// that replays the animation. Stateful so the replayTick survives dialog
// rebuilds while the user pops out and back.
// ─────────────────────────────────────────────────────────────────────────────

class _FullPreviewDialog extends StatefulWidget {
  const _FullPreviewDialog({
    required this.path,
    required this.caption,
    required this.priceTag,
    required this.mrpTag,
    required this.offerBadge,
    required this.textPosition,
    required this.badgeSize,
    required this.captionStyle,
    required this.captionStyleId,
    required this.captionUppercase,
    required this.captionRotation,
    required this.animStyle,
    required this.badgeStyle,
    required this.badgeAnimStyle,
    required this.bgRemoval,
    required this.bgColorArgb,
    required this.isVideo,
  });

  final String path;
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;
  final CaptionStyle captionStyle;
  final String captionStyleId;
  final bool captionUppercase;
  final int captionRotation;
  final String animStyle;
  final BadgeStyle badgeStyle;
  final String badgeAnimStyle;
  final bool bgRemoval;
  final int bgColorArgb;
  final bool isVideo;

  @override
  State<_FullPreviewDialog> createState() => _FullPreviewDialogState();
}

class _FullPreviewDialogState extends State<_FullPreviewDialog> {
  int _replayTick = 0;

  @override
  void initState() {
    super.initState();
    // Auto-play on open so users see the entrance animation immediately
    // after tapping Fullscreen.
    if (widget.animStyle != 'none' && widget.caption.isNotEmpty) {
      _replayTick = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPlay =
        widget.caption.isNotEmpty && widget.animStyle != 'none';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.isVideo
                      ? _FullscreenVideoPreview(
                          path: widget.path,
                          caption: widget.caption,
                          priceTag: widget.priceTag,
                          mrpTag: widget.mrpTag,
                          offerBadge: widget.offerBadge,
                          textPosition: widget.textPosition,
                          badgeSize: widget.badgeSize,
                          captionStyle: widget.captionStyle,
                          uppercase: widget.captionUppercase,
                          rotationDegrees: widget.captionRotation,
                          animStyle: widget.animStyle,
                          replayTick: _replayTick,
                          badgeStyle: widget.badgeStyle,
                          badgeAnimStyle: widget.badgeAnimStyle,
                        )
                      : _LiveThumbnail(
                          path: widget.path,
                          caption: widget.caption,
                          priceTag: widget.priceTag,
                          mrpTag: widget.mrpTag,
                          offerBadge: widget.offerBadge,
                          badgeSize: widget.badgeSize,
                          textPosition: widget.textPosition,
                          captionStyleId: widget.captionStyleId,
                          captionStyleOverride: widget.captionStyle,
                          uppercase: widget.captionUppercase,
                          rotationDegrees: widget.captionRotation,
                          animStyle: widget.animStyle,
                          replayTick: _replayTick,
                          badgeStyle: widget.badgeStyle,
                          badgeAnimStyle: widget.badgeAnimStyle,
                          fullSize: true,
                          bgRemoval: widget.bgRemoval,
                          bgColorArgb: widget.bgColorArgb,
                        ),
                  if (showPlay)
                    Positioned(
                      bottom: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              PrHaptics.tap();
                              setState(() => _replayTick++);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.brandEmber
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 4),
                                  Text('Replay',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -14,
            right: -14,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
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
    );
  }
}

class _FullscreenVideoPreview extends StatefulWidget {
  const _FullscreenVideoPreview({
    required this.path,
    required this.caption,
    required this.priceTag,
    required this.mrpTag,
    required this.offerBadge,
    required this.textPosition,
    required this.badgeSize,
    required this.captionStyle,
    required this.uppercase,
    required this.rotationDegrees,
    this.animStyle = 'none',
    this.replayTick = 0,
    this.badgeStyle,
    this.badgeAnimStyle = 'none',
  });
  final String path;
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;
  final CaptionStyle captionStyle;
  final bool uppercase;
  final int rotationDegrees;
  final String animStyle;
  final int replayTick;
  final BadgeStyle? badgeStyle;
  final String badgeAnimStyle;

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
            captionStyle: widget.captionStyle,
            badgeStyle: widget.badgeStyle,
            badgeAnimStyle: widget.badgeAnimStyle,
            uppercase: widget.uppercase,
            rotationDegrees: widget.rotationDegrees,
            animStyle: widget.animStyle,
            replayTick: widget.replayTick,
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
class _OverlayLayer extends StatefulWidget {
  const _OverlayLayer({
    required this.caption,
    required this.priceTag,
    required this.mrpTag,
    required this.offerBadge,
    required this.textPosition,
    required this.badgeSize,
    this.captionStyle,
    this.badgeStyle,
    this.badgeAnimStyle = 'none',
    this.uppercase = false,
    this.rotationDegrees = 0,
    this.animStyle = 'none',
    this.replayTick = 0,
  });
  final String caption;
  final String priceTag;
  final String mrpTag;
  final String offerBadge;
  final String textPosition;
  final String badgeSize;

  /// Resolved caption style (preset + per-frame overrides). Null falls back
  /// to [CaptionStyle.defaultStyle] so legacy callers don't crash.
  final CaptionStyle? captionStyle;

  /// Resolved per-frame badge style. Null falls back to the default preset.
  final BadgeStyle? badgeStyle;
  final String badgeAnimStyle;
  final bool uppercase;
  final int rotationDegrees;
  final String animStyle;
  final int replayTick;

  @override
  State<_OverlayLayer> createState() => _OverlayLayerState();
}

class _OverlayLayerState extends State<_OverlayLayer>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _durationFor(widget.animStyle),
    )..addListener(() => setState(() {}));
    // Auto-play on mount — users open the Fullscreen dialog wanting to see
    // the animation, so fire it once as soon as the layer lives.
    if (widget.animStyle != 'none' && widget.caption.isNotEmpty) {
      _ctrl!
        ..value = 0.0
        ..forward();
    } else {
      _ctrl!.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_OverlayLayer old) {
    super.didUpdateWidget(old);
    if (old.replayTick != widget.replayTick) {
      _ctrl?.duration = _durationFor(widget.animStyle);
      _ctrl
        ?..value = 0.0
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Duration _durationFor(String style) {
    switch (style) {
      case 'fade':
      case 'slide_up':
      case 'wipe':
        return const Duration(milliseconds: 350);
      case 'pop':
        return const Duration(milliseconds: 300);
      case 'typewriter':
        return const Duration(milliseconds: 800);
      default:
        return const Duration(milliseconds: 300);
    }
  }

  /// Mirrors `_LiveThumbnailState._applyEntrance`, but scoped to the
  /// overlay layer — keeps the Fullscreen video preview in sync with the
  /// inline preview's animation math.
  Widget _applyEntrance({
    required Widget child,
    required double progress,
    required double fontSize,
  }) {
    if (progress >= 1.0) return child;
    switch (widget.animStyle) {
      case 'fade':
        return Opacity(opacity: progress.clamp(0, 1), child: child);
      case 'slide_up':
        final dy = (1 - progress) * (fontSize * 4);
        return Transform.translate(offset: Offset(0, dy), child: child);
      case 'pop':
        final s = (0.6 + 0.4 * progress).clamp(0.6, 1.0);
        return Transform.scale(scale: s, child: child);
      case 'typewriter':
      case 'wipe':
        final dx = (1 - progress) * -300.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      default:
        return child;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adapter locals that let the existing build code continue to work
    // without being rewritten — they read straight from `widget`.
    final caption = widget.caption;
    final priceTag = widget.priceTag;
    final mrpTag = widget.mrpTag;
    final offerBadge = widget.offerBadge;
    final textPosition = widget.textPosition;
    final badgeSize = widget.badgeSize;
    final captionStyle = widget.captionStyle;
    final uppercase = widget.uppercase;
    final rotationDegrees = widget.rotationDegrees;
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

    final style = captionStyle ?? CaptionStyle.defaultStyle;
    final displayCaption = uppercase ? caption.toUpperCase() : caption;
    final pos = TextPosition.parse(textPosition);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Caption painted in the active style (pill + effect + font)
        // with the active entrance animation on top.
        if (caption.isNotEmpty)
          Align(
            alignment:
                Alignment(pos.offset.dx * 2 - 1, pos.offset.dy * 2 - 1),
            child: _applyEntrance(
              progress: _ctrl?.value ?? 1.0,
              fontSize: 16,
              child: Transform.rotate(
                angle: rotationDegrees * 3.14159265358979 / 180.0,
                child: _styledCaption(
                    text: displayCaption, style: style, fontSize: 16),
              ),
            ),
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

        // Offer badge — shared StyledBadge with entrance animation.
        if (offerBadge.isNotEmpty)
          Positioned(
            top: edge,
            left: edge,
            child: _applyBadgeEntrance(
              animStyle: widget.badgeAnimStyle,
              progress: _ctrl?.value ?? 1.0,
              child: StyledBadge(
                style: widget.badgeStyle ?? BadgeStyle.defaultStyle,
                text: offerBadge.replaceAll(' 🔥', ''),
                fontSize: badgeFontSize,
              ),
            ),
          ),
      ],
    );
  }

  Widget _applyBadgeEntrance({
    required Widget child,
    required String animStyle,
    required double progress,
  }) {
    if (progress >= 1.0) return child;
    switch (animStyle) {
      case 'pop':
        final s = (0.5 + 0.5 * progress).clamp(0.5, 1.0);
        return Transform.scale(scale: s, child: child);
      case 'slide_in':
        final dx = (1 - progress) * -120.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      case 'rotate_in':
        final angle = (1 - progress) * 0.7;
        final s = (0.6 + 0.4 * progress).clamp(0.6, 1.0);
        return Transform.rotate(
          angle: -angle,
          child: Transform.scale(scale: s, child: child),
        );
      case 'pulse':
        final peak = 1 - (progress * 2 - 1).abs();
        return Transform.scale(
          scale: (1.0 + 0.2 * peak).clamp(1.0, 1.2),
          child: child,
        );
      default:
        return child;
    }
  }

  Widget _styledCaption({
    required String text,
    required CaptionStyle style,
    required double fontSize,
  }) {
    final double padH = fontSize * 0.75;
    final double padV = fontSize * 0.35;
    final double radius = fontSize * 0.7;
    return IntrinsicWidth(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: style.pillColor != null
            ? BoxDecoration(
                color: style.pillColor,
                borderRadius: BorderRadius.circular(radius),
              )
            : null,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: googleFontsStyleFor(style, fontSize: fontSize),
        ),
      ),
    );
  }
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
// Free-form badge text field — the label for the offer badge. Custom text
// replaces the old fixed chip picker; users can type anything up to 18
// chars. Stateful so it manages its own controller without us having to
// plumb a list of TextEditingControllers through the frame card tree.
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeTextField extends StatefulWidget {
  const _BadgeTextField({required this.text, required this.onChanged});
  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<_BadgeTextField> createState() => _BadgeTextFieldState();
}

class _BadgeTextFieldState extends State<_BadgeTextField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(_BadgeTextField old) {
    super.didUpdateWidget(old);
    // External (quick-chip) change — sync the controller but preserve
    // cursor position when the user is typing the same value back.
    if (widget.text != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: _ctrl,
        maxLength: 18,
        textCapitalization: TextCapitalization.characters,
        style: AppTextStyles.bodySmall.copyWith(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'e.g. SALE · 50% OFF · FREE DELIVERY',
          hintStyle: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textDisabled, fontSize: 12),
          counterStyle: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textDisabled, fontSize: 10),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick badge chip — one-tap shortcut to a common label. Tapping writes
// the label straight into the offer-badge text; tapping an already-
// selected chip clears it. Style/shape/color live on the separate Badge
// Style row.
// ─────────────────────────────────────────────────────────────────────────────

class _QuickBadgeChip extends StatelessWidget {
  const _QuickBadgeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brandEmber : AppColors.textSecondary;
    final bg = selected
        ? AppColors.brandEmber.withValues(alpha: 0.14)
        : AppColors.bgElevated;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brandEmber : AppColors.divider,
            width: 1,
          ),
        ),
        child: Text(label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge style toolbar — live preview chip on the left + four axis
// launchers on the right (Style / Fill / Text / Motion). Follows the same
// pattern as `_CaptionStyleToolbar` so users don't have to re-learn a
// second interaction model.
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeStyleToolbar extends StatelessWidget {
  const _BadgeStyleToolbar({
    required this.styleId,
    required this.resolvedStyle,
    required this.animStyle,
    required this.sampleText,
    required this.onStylePicked,
    required this.onFillColorPicked,
    required this.onTextColorPicked,
    required this.onAnimPicked,
  });

  final String styleId;
  final BadgeStyle resolvedStyle;
  final String animStyle;
  final String sampleText;
  final ValueChanged<String> onStylePicked;
  final ValueChanged<int> onFillColorPicked;
  final ValueChanged<int> onTextColorPicked;
  final ValueChanged<String> onAnimPicked;

  @override
  Widget build(BuildContext context) {
    final preview = sampleText.isEmpty ? 'SALE' : sampleText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            // Cap the live preview's footprint so starburst/ribbon tiles
            // don't overflow the toolbar row.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: StyledBadge(
                style: resolvedStyle,
                text: preview.replaceAll(' 🔥', ''),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AxisButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Style',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showBadgeStyleSheet(
                      context,
                      initialStyleId: styleId,
                      sampleText: preview,
                    );
                    if (picked != null) onStylePicked(picked);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.format_color_fill_rounded,
                  label: 'Fill',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showBadgeColorSheet(
                      context,
                      currentStyle: resolvedStyle,
                      axis: BadgeColorAxis.fill,
                    );
                    if (picked != null) onFillColorPicked(picked);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.format_color_text_rounded,
                  label: 'Text',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showBadgeColorSheet(
                      context,
                      currentStyle: resolvedStyle,
                      axis: BadgeColorAxis.text,
                    );
                    if (picked != null) onTextColorPicked(picked);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.animation_rounded,
                  label: 'Motion',
                  active: animStyle.isNotEmpty && animStyle != 'none',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showBadgeAnimSheet(
                      context,
                      currentAnim: animStyle,
                    );
                    if (picked != null) onAnimPicked(picked);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption style toolbar — a compact row of axis launchers (Style / Font /
// Color / Effect / Aa-uppercase). Each button opens a focused bottom sheet
// for that one axis; state changes flow through individual callbacks so
// `_FrameCard` stays dumb. Live preview chip on the left shows the current
// combined look (preset + overrides + uppercase) so users see edits reflected
// without tapping into each sheet.
// ─────────────────────────────────────────────────────────────────────────────

class _CaptionStyleToolbar extends StatelessWidget {
  const _CaptionStyleToolbar({
    required this.resolvedStyle,
    required this.styleId,
    required this.uppercase,
    required this.rotationDegrees,
    required this.animStyle,
    required this.sampleText,
    required this.onStylePicked,
    required this.onFontPicked,
    required this.onTextColorPicked,
    required this.onPillColorPicked,
    required this.onEffectPicked,
    required this.onUppercaseToggled,
    required this.onMotionPicked,
    required this.onRotationChanged,
  });

  final CaptionStyle resolvedStyle;
  final String styleId;
  final bool uppercase;
  final int rotationDegrees;
  final String animStyle;
  final String sampleText;
  final ValueChanged<String> onStylePicked;
  final ValueChanged<String> onFontPicked;
  final ValueChanged<int> onTextColorPicked;
  final ValueChanged<int> onPillColorPicked;
  final ValueChanged<String> onEffectPicked;
  final ValueChanged<bool> onUppercaseToggled;
  final ValueChanged<String> onMotionPicked;
  final ValueChanged<int> onRotationChanged;

  @override
  Widget build(BuildContext context) {
    final previewText = sampleText.isEmpty ? 'Aa' : sampleText;
    final displayText = uppercase ? previewText.toUpperCase() : previewText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live styled preview of the caption — shrinks to fit. Rotates
          // with the frame's tilt so users can preview sticker-style poses.
          Center(
            child: Transform.rotate(
              angle: rotationDegrees * 3.14159265358979 / 180.0,
              child: _LiveStylePreview(
                style: resolvedStyle,
                displayText: _chipSample(displayText),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AxisButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Style',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showCaptionStyleSheet(
                      context,
                      initialStyleId: styleId,
                      sampleText: sampleText,
                    );
                    if (picked != null) onStylePicked(picked);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.text_fields_rounded,
                  label: 'Font',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showCaptionFontSheet(
                      context,
                      currentFamily: resolvedStyle.fontFamily,
                      sampleText: sampleText,
                    );
                    if (picked != null) onFontPicked(picked);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.palette_rounded,
                  label: 'Color',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showCaptionColorSheet(
                      context,
                      currentStyle: resolvedStyle,
                      hasPill: resolvedStyle.pillColor != null,
                    );
                    if (picked == null) return;
                    if (picked.textColor != null) {
                      onTextColorPicked(picked.textColor!);
                    }
                    if (picked.pillColor != null) {
                      onPillColorPicked(picked.pillColor!);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _AxisButton(
                  icon: Icons.blur_on_rounded,
                  label: 'Effect',
                  onTap: () async {
                    PrHaptics.tap();
                    final picked = await showCaptionEffectSheet(
                      context,
                      currentStyle: resolvedStyle,
                    );
                    if (picked != null) onEffectPicked(picked);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.animation_rounded,
                  label: 'Motion',
                  active: animStyle != 'none' || rotationDegrees != 0,
                  onTap: () async {
                    PrHaptics.tap();
                    final result = await showCaptionMotionSheet(
                      context,
                      currentAnimStyle: animStyle,
                      currentRotation: rotationDegrees,
                    );
                    if (result == null) return;
                    if (result.animStyle != null) {
                      onMotionPicked(result.animStyle!);
                    }
                    if (result.rotation != null) {
                      onRotationChanged(result.rotation!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AxisButton(
                  icon: Icons.abc_rounded,
                  label: 'Aa',
                  active: uppercase,
                  onTap: () {
                    PrHaptics.select();
                    onUppercaseToggled(!uppercase);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _chipSample(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return 'Aa';
    if (trimmed.length <= 20) return trimmed;
    return '${trimmed.substring(0, 20)}…';
  }
}

class _LiveStylePreview extends StatelessWidget {
  const _LiveStylePreview({required this.style, required this.displayText});
  final CaptionStyle style;
  final String displayText;

  @override
  Widget build(BuildContext context) {
    const double fontPx = 16;
    final double padH = fontPx * 0.75;
    final double padV = fontPx * 0.35;
    final double radius = fontPx * 0.7;
    return IntrinsicWidth(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: style.pillColor != null
            ? BoxDecoration(
                color: style.pillColor,
                borderRadius: BorderRadius.circular(radius),
              )
            : null,
        child: Text(
          displayText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: googleFontsStyleFor(style, fontSize: fontPx),
        ),
      ),
    );
  }
}

class _AxisButton extends StatelessWidget {
  const _AxisButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.brandEmber : AppColors.textSecondary;
    final bg = active
        ? AppColors.brandEmber.withValues(alpha: 0.16)
        : Colors.transparent;
    final border = active ? AppColors.brandEmber : AppColors.divider;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption position picker — three segmented chips (Top / Middle / Bottom).
// Writes a legacy preset string into frameTextPositions, which the renderer
// and preview already know how to handle.
// ─────────────────────────────────────────────────────────────────────────────

class _CaptionPositionPicker extends StatelessWidget {
  const _CaptionPositionPicker({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = <(String, IconData, String)>[
    ('top', Icons.vertical_align_top_rounded, 'Top'),
    ('center', Icons.vertical_align_center_rounded, 'Middle'),
    ('bottom', Icons.vertical_align_bottom_rounded, 'Bottom'),
  ];

  @override
  Widget build(BuildContext context) {
    // Any `custom:*` legacy value falls back to 'bottom' for display.
    final current = _options.any((o) => o.$1 == selected) ? selected : 'bottom';
    return Row(
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _PositionChip(
              icon: _options[i].$2,
              label: _options[i].$3,
              selected: current == _options[i].$1,
              onTap: () {
                PrHaptics.select();
                onSelected(_options[i].$1);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PositionChip extends StatelessWidget {
  const _PositionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.brandEmber.withValues(alpha: 0.18)
        : AppColors.bgElevated;
    final border =
        selected ? AppColors.brandEmber : AppColors.divider;
    final fg = selected ? AppColors.brandEmber : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
