class VenueModel {
  final String id;
  final String name;
  final String? logo; // filename like "hams.png"

  VenueModel({
    required this.id,
    required this.name,
    this.logo,
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logo: json['logo']?.toString(),
    );
  }
}
