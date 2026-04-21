import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/branding_preset.dart';
import '../data/services/branding_service.dart';

/// Multi-kit branding state: every saved kit plus the id of the active one.
class BrandKitsState {
  const BrandKitsState({required this.kits, required this.activeId});
  final List<BrandingPreset> kits;
  final String? activeId;

  BrandKitsState copyWith({List<BrandingPreset>? kits, Object? activeId = _sentinel}) {
    return BrandKitsState(
      kits: kits ?? this.kits,
      activeId: activeId == _sentinel ? this.activeId : activeId as String?,
    );
  }

  BrandingPreset? get active {
    if (kits.isEmpty) return null;
    return kits.firstWhere(
      (k) => k.id == activeId,
      orElse: () => kits.first,
    );
  }

  static const _sentinel = Object();
}

class BrandKitsNotifier extends StateNotifier<BrandKitsState> {
  BrandKitsNotifier(this._service)
      : super(const BrandKitsState(kits: [], activeId: null)) {
    _loadFuture = _load();
  }

  final BrandingService _service;
  late final Future<void> _loadFuture;

  /// Await this before reading branding state in time-sensitive paths (e.g. export).
  Future<void> ensureLoaded() => _loadFuture;

  Future<void> _load() async {
    final all = await _service.loadAll();
    if (!mounted) return;
    state = BrandKitsState(kits: all.kits, activeId: all.activeId);
  }

  /// Save a kit (create or update) and make it active unless told otherwise.
  Future<void> save(BrandingPreset kit, {bool activate = true}) async {
    await _service.save(kit, activate: activate);
    final idx = state.kits.indexWhere((k) => k.id == kit.id);
    final nextKits = idx >= 0
        ? [...state.kits.sublist(0, idx), kit, ...state.kits.sublist(idx + 1)]
        : [...state.kits, kit];
    state = BrandKitsState(
      kits: nextKits,
      activeId: activate ? kit.id : state.activeId ?? kit.id,
    );
  }

  Future<void> setActive(String id) async {
    await _service.setActive(id);
    state = state.copyWith(activeId: id);
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    final nextKits = state.kits.where((k) => k.id != id).toList();
    final nextActive = nextKits.isEmpty
        ? null
        : (state.activeId == id ? nextKits.first.id : state.activeId);
    state = BrandKitsState(kits: nextKits, activeId: nextActive);
  }
}

final brandingServiceProvider = Provider((ref) => BrandingService());

/// Full multi-kit state: list of saved kits + the active id.
/// Use this from the branding screen when showing the kit switcher.
final brandKitsProvider =
    StateNotifierProvider<BrandKitsNotifier, BrandKitsState>(
  (ref) => BrandKitsNotifier(ref.read(brandingServiceProvider)),
);

/// The active kit — preserved API so editor/export paths that read a single
/// `BrandingPreset` keep working. Writing to this provider updates (and
/// activates) the same kit in the multi-kit store.
final brandingProvider =
    StateNotifierProvider<_ActiveKitNotifier, BrandingPreset>((ref) {
  return _ActiveKitNotifier(ref);
});

/// Thin adapter exposing the active kit as a single `BrandingPreset` value
/// so call sites don't need to know about the multi-kit list. Listens to
/// [brandKitsProvider] and mirrors the active kit into its own state.
class _ActiveKitNotifier extends StateNotifier<BrandingPreset> {
  _ActiveKitNotifier(this._ref)
      : super(const BrandingPreset(id: 'default', name: 'Default')) {
    final kits = _ref.read(brandKitsProvider);
    if (kits.active != null) state = kits.active!;
    _ref.listen<BrandKitsState>(brandKitsProvider, (prev, next) {
      if (next.active != null) state = next.active!;
    });
  }

  final Ref _ref;

  Future<void> ensureLoaded() =>
      _ref.read(brandKitsProvider.notifier).ensureLoaded();

  Future<void> save(BrandingPreset preset) =>
      _ref.read(brandKitsProvider.notifier).save(preset);

  Future<void> updateLogoPath(String? path) {
    final updated = BrandingPreset(
      id: state.id,
      name: state.name,
      businessName: state.businessName,
      phoneNumber: state.phoneNumber,
      address: state.address,
      logoPath: path,
    );
    return save(updated);
  }
}
