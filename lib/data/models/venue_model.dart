// lib/data/models/venue_model.dart
class VenueModel {
  final String id;
  final String name;
  final String logoUrl;

  VenueModel({
    required this.id,
    required this.name,
    required this.logoUrl,
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: (json['logoUrl'] ?? '').toString(),
    );
  }
}
