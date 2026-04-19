import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/whatsapp_share.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoPath});
  final String videoPath;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _showControls = true;
  bool _fileError = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.videoPath.isEmpty || !File(widget.videoPath).existsSync()) {
      if (mounted) setState(() => _fileError = true);
      return;
    }
    final ctrl = VideoPlayerController.file(File(widget.videoPath));
    _ctrl = ctrl;
    ctrl.addListener(_onPlayerUpdate);
    await ctrl.initialize();
    if (mounted) {
      setState(() => _initialized = true);
      ctrl.play();
      ctrl.setLooping(true);
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onPlayerUpdate);
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  Future<void> _share() async {
    await WhatsAppShare.shareVideo(widget.videoPath);
  }

  @override
  Widget build(BuildContext context) {
    if (_fileError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    Text('Preview', style: AppTextStyles.titleLarge),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, color: Colors.white38, size: 56),
                      SizedBox(height: 12),
                      Text('Video file not found', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  Text('Preview', style: AppTextStyles.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: _share,
                    tooltip: 'Share',
                  ),
                ],
              ),
            ),
            // Video area
            Expanded(
              child: GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _initialized && _ctrl != null
                        ? Center(
                            child: AspectRatio(
                              aspectRatio: _ctrl!.value.aspectRatio,
                              child: VideoPlayer(_ctrl!),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(color: AppColors.primary)),
                    if (_showControls && _initialized && _ctrl != null)
                      _ControlsOverlay(
                        controller: _ctrl!,
                        onPlayPause: _togglePlayPause,
                      ),
                  ],
                ),
              ),
            ),
            // Progress bar + share button
            if (_initialized && _ctrl != null)
              _BottomBar(controller: _ctrl!, onShare: _share),
          ],
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller, required this.onPlayPause});
  final VideoPlayerController controller;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x88000000), Colors.transparent],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onShare});
  final VideoPlayerController controller;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final pos = controller.value.position;
    final dur = controller.value.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.black,
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final target = Duration(milliseconds: (v * dur.inMilliseconds).toInt());
                controller.seekTo(target);
              },
            ),
          ),
          Row(
            children: [
              Text(_fmt(pos), style: AppTextStyles.labelSmall.copyWith(color: Colors.white54, fontSize: 11)),
              const Spacer(),
              Text(_fmt(dur), style: AppTextStyles.labelSmall.copyWith(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Share to WhatsApp Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
