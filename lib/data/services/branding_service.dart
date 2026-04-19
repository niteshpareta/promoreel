import 'package:shared_preferences/shared_preferences.dart';
import '../models/branding_preset.dart';

class BrandingService {
  static const _kId            = 'brand_id';
  static const _kName          = 'brand_name';
  static const _kBusinessName  = 'brand_business_name';
  static const _kPhone         = 'brand_phone';
  static const _kAddress       = 'brand_address';
  static const _kLogoPath      = 'brand_logo_path';

  Future<BrandingPreset?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kId);
    if (id == null) return null;
    return BrandingPreset(
      id: id,
      name: prefs.getString(_kName) ?? 'Default',
      businessName: prefs.getString(_kBusinessName) ?? '',
      phoneNumber: prefs.getString(_kPhone) ?? '',
      address: prefs.getString(_kAddress) ?? '',
      logoPath: prefs.getString(_kLogoPath),
    );
  }

  Future<void> save(BrandingPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kId, preset.id);
    await prefs.setString(_kName, preset.name);
    await prefs.setString(_kBusinessName, preset.businessName);
    await prefs.setString(_kPhone, preset.phoneNumber);
    await prefs.setString(_kAddress, preset.address);
    if (preset.logoPath != null) {
      await prefs.setString(_kLogoPath, preset.logoPath!);
    } else {
      await prefs.remove(_kLogoPath);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_kId, _kName, _kBusinessName, _kPhone, _kAddress, _kLogoPath]) {
      await prefs.remove(key);
    }
  }
}
