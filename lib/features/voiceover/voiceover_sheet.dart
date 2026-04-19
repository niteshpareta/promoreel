import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/video_project.dart';
import '../../providers/project_provider.dart';

void showVoiceoverSheet(BuildContext context, {int initialFrameIndex = 0}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _VoiceoverSheet(initialFrameIndex: initialFrameIndex),
  );
}

class _VoiceoverSheet extends ConsumerStatefulWidget {
  const _VoiceoverSheet({required this.initialFrameIndex});
  final int initialFrameIndex;

  @override
  ConsumerState<_VoiceoverSheet> createState() => _VoiceoverSheetState();
}

class _VoiceoverSheetState extends ConsumerState<_VoiceoverSheet> {
  final _recorder = AudioRecorder();
  late int _selectedFrame;

  bool _recording = false;
  String? _recordingPath;
  int _seconds = 0;
  Timer? _timer;
  double _amplitude = 0;
  StreamSubscription<Amplitude>? _ampSub;

  @override
  void initState() {
    super.initState();
    _selectedFrame = widget.initialFrameIndex;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  VideoProject? get _project => ref.read(projectProvider);

  String? _existingVoiceover(int frame) {
    final vos = _project?.frameVoiceovers ?? [];
    if (frame >= vos.length) return null;
    final path = vos[frame];
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  Future<String> _outputPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/vo_frame${_selectedFrame}_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    final path = await _outputPath();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      if (mounted) setState(() => _amplitude = ((amp.current + 60) / 60).clamp(0, 1));
    });

    _seconds = 0;
    final maxSec = _frameDuration(_selectedFrame);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= maxSec) _stopRecording();
    });

    setState(() { _recording = true; _recordingPath = path; });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _ampSub?.cancel();
    await _recorder.stop();
    setState(() { _recording = false; _amplitude = 0; });
  }

  int _frameDuration(int frame) {
    final durations = _project?.frameDurations ?? [];
    if (frame < durations.length) return durations[frame];
    return 3;
  }

  void _apply() {
    if (_recordingPath != null) {
      ref.read(projectProvider.notifier).setFrameVoiceover(_selectedFrame, _recordingPath);
    }
    Navigator.pop(context);
  }

  void _remove() {
    ref.read(projectProvider.notifier).setFrameVoiceover(_selectedFrame, null);
    setState(() { _recordingPath = null; _seconds = 0; });
  }

  void _selectFrame(int i) {
    if (_recording) return;
    setState(() {
      _selectedFrame = i;
      _recordingPath = null;
      _seconds = 0;
    });
  }

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    if (project == null) return const SizedBox.shrink();

    final frameCount = project.assetPaths.length;
    final existing = _existingVoiceover(_selectedFrame);
    final hasRecording = _recordingPath != null || existing != null;
    final maxSec = _frameDuration(_selectedFrame);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text('Voice-over', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Record narration for each slide individually',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Slide selector with thumbnails
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: frameCount,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = i == _selectedFrame;
                final hasVo = (project.frameVoiceovers.length > i &&
                    project.frameVoiceovers[i] != null);
                final path = project.assetPaths[i];
                return GestureDetector(
                  onTap: () => _selectFrame(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppColors.primary : AppColors.divider,
                        width: sel ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.5),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _SlideThumbnail(path: path),
                          // Slide number label at bottom
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('${i + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          // Voiceover recorded indicator
                          if (hasVo)
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success,
                                  border: Border.all(
                                      color: Colors.black54, width: 1),
                                ),
                              ),
                            ),
                          // Selected overlay tint
                          if (sel)
                            Positioned.fill(
                              child: Container(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Slide ${_selectedFrame + 1}  •  ${maxSec}s',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Waveform / status display
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _recording
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 4, height: 14 + _amplitude * 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                color: Color(0xFFE53935), size: 10),
                            Text(_formatTime(_seconds),
                                style: AppTextStyles.titleLarge.copyWith(
                                    color: AppColors.textPrimary,
                                    fontFamily: 'monospace')),
                            Text('Recording…  (max ${maxSec}s)',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 4, height: 14 + _amplitude * 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    )
                  : hasRecording
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              _recordingPath != null
                                  ? 'New recording ready'
                                  : 'Voice-over saved',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic_none_rounded,
                                color: AppColors.textDisabled, size: 24),
                            const SizedBox(height: 4),
                            Text('Tap record — narrate this slide',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textDisabled)),
                          ],
                        ),
            ),
          ),

          const SizedBox(height: 20),

          // Record / Stop button
          GestureDetector(
            onTap: _recording ? _stopRecording : _startRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording ? const Color(0xFFE53935) : AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: (_recording ? const Color(0xFFE53935) : AppColors.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 16, offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white, size: 28,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _recording ? 'Tap to stop' : 'Tap to record',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 20),

          if (hasRecording) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Voice-over'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Slide thumbnail widget ────────────────────────────────────────────────────

class _SlideThumbnail extends StatefulWidget {
  const _SlideThumbnail({required this.path});
  final String path;

  @override
  State<_SlideThumbnail> createState() => _SlideThumbnailState();
}

class _SlideThumbnailState extends State<_SlideThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.path == kTextSlide || isBeforeAfterPath(widget.path)) return;
    final ext = widget.path.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(ext);
    if (isVideo) {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 160,
        quality: 60,
      );
      if (mounted) setState(() => _thumb = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;

    // Text slide
    if (path == kTextSlide) {
      return Container(
        color: const Color(0xFF1E0A4A),
        child: const Center(
          child: Icon(Icons.text_fields_rounded,
              color: Colors.white38, size: 20),
        ),
      );
    }

    // Before/After slide
    if (isBeforeAfterPath(path)) {
      final parts = decodeBeforeAfter(path);
      Widget half(String p) => File(p).existsSync()
          ? Image.file(File(p), fit: BoxFit.cover,
              width: double.infinity, height: double.infinity)
          : Container(color: AppColors.bgSurfaceVariant);
      return Row(
        children: [
          Expanded(child: ClipRect(child: half(parts[0]))),
          Container(width: 1, color: Colors.white54),
          Expanded(child: ClipRect(child: half(parts[1]))),
        ],
      );
    }

    // Video with thumbnail
    if (_thumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_thumb!, fit: BoxFit.cover),
          const Center(
            child: Icon(Icons.play_circle_outline_rounded,
                color: Colors.white70, size: 18),
          ),
        ],
      );
    }

    // Regular image
    if (File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }

    return Container(color: AppColors.bgSurfaceVariant);
  }
}
