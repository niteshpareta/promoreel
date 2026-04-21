import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/branding_preset.dart';

/// Persistent storage for branding kits.
///
/// Multiple kits (e.g. "Main Shop", "Branch", "Event") are stored as a
/// JSON-encoded list in SharedPreferences; exactly one is marked active
/// via a separate key. Legacy single-preset storage from the pre-multi-kit
/// build is auto-migrated on first read.
class BrandingService {
  // v2 multi-kit storage.
  static const _kKits     = 'brand_kits_v2';
  static const _kActiveId = 'brand_active_id';

  // Legacy single-preset keys (still read once for migration).
  static const _kLegacyId            = 'brand_id';
  static const _kLegacyName          = 'brand_name';
  static const _kLegacyBusinessName  = 'brand_business_name';
  static const _kLegacyPhone         = 'brand_phone';
  static const _kLegacyAddress       = 'brand_address';
  static const _kLegacyLogoPath      = 'brand_logo_path';

  /// Load all kits + the active id. Runs a one-shot migration from the
  /// legacy single-preset schema the first time it sees old data.
  Future<({List<BrandingPreset> kits, String? activeId})> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKits);

    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
      return (kits: list, activeId: prefs.getString(_kActiveId));
    }

    // Migration path — read the legacy single preset if present.
    final legacyId = prefs.getString(_kLegacyId);
    if (legacyId != null) {
      final migrated = BrandingPreset(
        id: legacyId,
        name: prefs.getString(_kLegacyName) ?? 'Default',
        businessName: prefs.getString(_kLegacyBusinessName) ?? '',
        phoneNumber: prefs.getString(_kLegacyPhone) ?? '',
        address: prefs.getString(_kLegacyAddress) ?? '',
        logoPath: prefs.getString(_kLegacyLogoPath),
      );
      await _writeAll(prefs, [migrated], migrated.id);
      await _clearLegacy(prefs);
      return (kits: [migrated], activeId: migrated.id);
    }

    return (kits: const <BrandingPreset>[], activeId: null);
  }

  /// Returns the currently-active kit, or null if no kits exist yet.
  Future<BrandingPreset?> load() async {
    final all = await loadAll();
    if (all.kits.isEmpty) return null;
    final id = all.activeId;
    return all.kits.firstWhere(
      (k) => k.id == id,
      orElse: () => all.kits.first,
    );
  }

  /// Create or update [preset]. If [activate] is true (the default), it also
  /// becomes the active kit.
  Future<void> save(BrandingPreset preset, {bool activate = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    final kits = [...all.kits];
    final existingIdx = kits.indexWhere((k) => k.id == preset.id);
    if (existingIdx >= 0) {
      kits[existingIdx] = preset;
    } else {
      kits.add(preset);
    }
    await _writeAll(
        prefs, kits, activate ? preset.id : (all.activeId ?? preset.id));
  }

  /// Remove a kit. If the active kit is deleted, the first remaining kit
  /// becomes active. Deleting the last kit clears active and the migration
  /// path will rebuild from nothing on next save.
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    final kits = all.kits.where((k) => k.id != id).toList();
    final nextActive = kits.isEmpty
        ? null
        : (all.activeId == id ? kits.first.id : all.activeId);
    await _writeAll(prefs, kits, nextActive);
  }

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveId, id);
  }

  /// Remove all branding data entirely (used by tests / full reset).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKits);
    await prefs.remove(_kActiveId);
    await _clearLegacy(prefs);
  }

  // ── internals ──────────────────────────────────────────────────────────────

  Future<void> _writeAll(
      SharedPreferences prefs, List<BrandingPreset> kits, String? activeId) async {
    final jsonList = kits.map(_toJson).toList();
    await prefs.setString(_kKits, jsonEncode(jsonList));
    if (activeId != null) {
      await prefs.setString(_kActiveId, activeId);
    } else {
      await prefs.remove(_kActiveId);
    }
  }

  Future<void> _clearLegacy(SharedPreferences prefs) async {
    for (final key in [
      _kLegacyId,
      _kLegacyName,
      _kLegacyBusinessName,
      _kLegacyPhone,
      _kLegacyAddress,
      _kLegacyLogoPath,
    ]) {
      await prefs.remove(key);
    }
  }

  static Map<String, dynamic> _toJson(BrandingPreset p) => {
        'id': p.id,
        'name': p.name,
        'businessName': p.businessName,
        'phoneNumber': p.phoneNumber,
        'address': p.address,
        'logoPath': p.logoPath,
      };

  static BrandingPreset _fromJson(Map<String, dynamic> m) => BrandingPreset(
        id: m['id'] as String,
        name: m['name'] as String? ?? 'Default',
        businessName: m['businessName'] as String? ?? '',
        phoneNumber: m['phoneNumber'] as String? ?? '',
        address: m['address'] as String? ?? '',
        logoPath: m['logoPath'] as String?,
      );
}
