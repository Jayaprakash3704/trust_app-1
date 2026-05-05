class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String address;
  final String role;

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.address,
    required this.role,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      role: data['role'] ?? 'user',
    );
  }
}
