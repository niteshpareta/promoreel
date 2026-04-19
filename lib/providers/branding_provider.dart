import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/branding_preset.dart';
import '../data/services/branding_service.dart';

class BrandingNotifier extends StateNotifier<BrandingPreset> {
  BrandingNotifier(this._service) : super(const BrandingPreset(id: 'default', name: 'Default')) {
    _loadFuture = _load();
  }

  final BrandingService _service;
  late final Future<void> _loadFuture;

  /// Await this before reading branding state in time-sensitive paths (e.g. export).
  Future<void> ensureLoaded() => _loadFuture;

  Future<void> _load() async {
    final preset = await _service.load();
    if (preset != null && mounted) state = preset;
  }

  Future<void> save(BrandingPreset preset) async {
    state = preset;
    await _service.save(preset);
  }

  Future<void> updateLogoPath(String? path) async {
    final updated = BrandingPreset(
      id: state.id,
      name: state.name,
      businessName: state.businessName,
      phoneNumber: state.phoneNumber,
      address: state.address,
      logoPath: path,
    );
    await save(updated);
  }
}

final brandingServiceProvider = Provider((ref) => BrandingService());

final brandingProvider = StateNotifierProvider<BrandingNotifier, BrandingPreset>(
  (ref) => BrandingNotifier(ref.read(brandingServiceProvider)),
);
