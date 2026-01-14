class BranchModel {
  final String id;
  final String name;
  final String address;
  final bool isAvailable;

  BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.isAvailable,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      isAvailable: json['isAvailable'] == true,
    );
  }
}
