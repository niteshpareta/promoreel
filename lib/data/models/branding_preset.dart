class BrandingPreset {
  const BrandingPreset({
    required this.id,
    required this.name,
    this.businessName = '',
    this.phoneNumber = '',
    this.address = '',
    this.logoPath,
  });

  final String id;
  final String name;
  final String businessName;
  final String phoneNumber;
  final String address;
  final String? logoPath;
}
