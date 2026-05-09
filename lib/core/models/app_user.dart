class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String address;
  final String role;
  final int monthlyBasicAmount;
  final int monthlyBasicDay;

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.address,
    required this.role,
    this.monthlyBasicAmount = 0,
    this.monthlyBasicDay = 1,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final rawAmount = data['monthlyBasicAmount'];
    final rawDay = data['monthlyBasicDay'];
    final amount = rawAmount is num ? rawAmount.toInt() : 0;
    final day = rawDay is num ? rawDay.toInt() : 1;

    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      role: data['role'] ?? 'user',
      monthlyBasicAmount: amount,
      monthlyBasicDay: day,
    );
  }
}
