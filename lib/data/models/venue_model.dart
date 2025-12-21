class VenueModel {
  final String id;
  final String name;
  final String type;
  final String logoUrl;

  VenueModel({
    required this.id,
    required this.name,
    required this.type,
    required this.logoUrl,
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      logoUrl: json['logoUrl'] ?? '',
    );
  }
}
