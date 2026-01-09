class ProfileModel {
  final String id;
  final String username;
  final String name;
  final String email;
  final String phone;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>) ? json['user'] as Map<String, dynamic> : json;

    return ProfileModel(
      id: (user['_id'] ?? user['id'] ?? '').toString(),
      username: (user['username'] ?? user['id'] ?? '').toString(),
      name: (user['name'] ?? user['fullName'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      phone: (user['phone'] ?? '').toString(),
    );
  }

  ProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
  }) {
    return ProfileModel(
      id: id,
      username: username,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}
