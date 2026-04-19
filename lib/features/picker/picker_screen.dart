import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../data/services/gallery_service.dart';
import '../../providers/project_provider.dart';

enum _PermStatus { checking, granted, denied, permanentlyDenied }

class PickerScreen extends ConsumerStatefulWidget {
  const PickerScreen({super.key});

  @override
  ConsumerState<PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends ConsumerState<PickerScreen>
    with WidgetsBindingObserver {
  _PermStatus _permStatus = _PermStatus.checking;
  List<AssetEntity> _assets = [];
  bool _loadingAssets = false;
  final List<AssetEntity> _selected = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when user returns from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _permStatus == _PermStatus.permanentlyDenied) {
      _checkAndRequest();
    }
  }

  Future<void> _checkAndRequest() async {
    setState(() => _permStatus = _PermStatus.checking);

    final perm = await _mediaPermission();
    var status = await perm.status;

    if (status.isDenied) {
      status = await perm.request();
    }

    if (status.isGranted || status.isLimited) {
      PhotoManager.setIgnorePermissionCheck(true);
      setState(() => _permStatus = _PermStatus.granted);
      await _loadAssets();
    } else if (status.isPermanentlyDenied) {
      setState(() => _permStatus = _PermStatus.permanentlyDenied);
    } else {
      setState(() => _permStatus = _PermStatus.denied);
    }
  }

  // Returns the correct permission for the current OS/version.
  Future<Permission> _mediaPermission() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      // Android 13+ (API 33) uses granular media permissions.
      return info.version.sdkInt >= 33
          ? Permission.photos
          : Permission.storage;
    }
    return Permission.photos; // iOS
  }

  Future<void> _requestPermission() async {
    if (_permStatus == _PermStatus.permanentlyDenied) {
      await openAppSettings();
      return;
    }
    await _checkAndRequest();
  }

  Future<void> _loadAssets() async {
    setState(() => _loadingAssets = true);
    try {
      final svc = GalleryService();
      final assets = await svc.loadAssets();
      if (mounted) setState(() { _assets = assets; _loadingAssets = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingAssets = false);
    }
  }

  void _toggle(AssetEntity asset) {
    setState(() {
      if (_selected.any((a) => a.id == asset.id)) {
        _selected.removeWhere((a) => a.id == asset.id);
      } else if (_selected.length < AppConstants.maxAssetsPerVideo) {
        _selected.add(asset);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Max ${AppConstants.maxAssetsPerVideo} files allowed'),
          backgroundColor: AppColors.bgElevated,
        ));
      }
    });
  }

  Future<void> _proceed() async {
    if (_selected.isEmpty) return;
    final svc = GalleryService();
    final paths = <String>[];
    for (final asset in _selected) {
      final file = await svc.getFile(asset);
      if (file != null) paths.add(file.path);
    }
    if (paths.isEmpty || !mounted) return;
    ref.read(projectProvider.notifier).startNew(paths);
    context.push(AppRoutes.editor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Media'),
            Text('Choose photos & videos for your Status',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _proceed,
              child: Text(
                '${_selected.length} selected ✓',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _SelectionBar(count: _selected.length),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: _proceed,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    '${_selected.length} selected — Continue',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_permStatus == _PermStatus.checking || _loadingAssets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permStatus == _PermStatus.denied ||
        _permStatus == _PermStatus.permanentlyDenied) {
      return _PermissionError(
        isPermanent: _permStatus == _PermStatus.permanentlyDenied,
        onAllow: _requestPermission,
      );
    }

    if (_assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: AppColors.textDisabled, size: 56),
            const SizedBox(height: 12),
            Text('No photos or videos found',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (ctx, i) {
        final asset = _assets[i];
        final selIdx = _selected.indexWhere((a) => a.id == asset.id);
        final isSelected = selIdx >= 0;
        return _AssetTile(
          asset: asset,
          isSelected: isSelected,
          selectionIndex: isSelected ? selIdx + 1 : null,
          onTap: () => _toggle(asset),
        );
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.bgSurface,
        child: Text(
          count == 0
              ? 'Select 1–${AppConstants.maxAssetsPerVideo} photos or videos'
              : '$count / ${AppConstants.maxAssetsPerVideo} selected',
          style: AppTextStyles.bodyMedium.copyWith(
            color: count == 0 ? AppColors.textSecondary : AppColors.primary,
          ),
        ),
      );
}

class _PermissionError extends StatelessWidget {
  const _PermissionError(
      {required this.isPermanent, required this.onAllow});
  final bool isPermanent;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_outlined,
                  color: AppColors.textDisabled, size: 56),
              const SizedBox(height: 16),
              Text('Gallery Access Required',
                  style: AppTextStyles.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                isPermanent
                    ? 'Permission was denied. Open Settings to allow access to your photos and videos.'
                    : 'PromoReel needs access to your photos and videos.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAllow,
                icon: Icon(isPermanent
                    ? Icons.settings_rounded
                    : Icons.photo_library_rounded),
                label: Text(isPermanent ? 'Open Settings' : 'Allow Access'),
              ),
            ],
          ),
        ),
      );
}

class _AssetTile extends StatefulWidget {
  const _AssetTile({
    required this.asset,
    required this.isSelected,
    required this.selectionIndex,
    required this.onTap,
  });
  final AssetEntity asset;
  final bool isSelected;
  final int? selectionIndex;
  final VoidCallback onTap;

  @override
  State<_AssetTile> createState() => _AssetTileState();
}

class _AssetTileState extends State<_AssetTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
      quality: 80,
    );
    if (mounted && data != null) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumb != null
              ? Image.memory(_thumb!, fit: BoxFit.cover)
              : Container(
                  color: AppColors.bgSurfaceVariant,
                  child: const Icon(Icons.image_rounded,
                      color: AppColors.textDisabled, size: 32)),
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_filled_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    _formatDuration(widget.asset.videoDuration),
                    style: AppTextStyles.labelSmall
                        .copyWith(color: Colors.white, fontSize: 9),
                  ),
                ],
              ),
            ),
          if (widget.isSelected)
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
            ),
          if (widget.isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.selectionIndex}',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
