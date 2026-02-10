class PersonModel {
  final String id;
  final String name;
  final double totalReceived;
  final double totalSpent;
  final double balance;

  PersonModel({
    required this.id,
    required this.name,
    this.totalReceived = 0.0,
    this.totalSpent = 0.0,
    this.balance = 0.0,
  });

  factory PersonModel.fromMap(Map<String, dynamic> map, String id) {
    return PersonModel(
      id: id,
      name: map['name'] ?? '',
      totalReceived: (map['totalReceived'] ?? 0.0).toDouble(),
      totalSpent: (map['totalSpent'] ?? 0.0).toDouble(),
      balance: (map['balance'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'totalReceived': totalReceived,
      'totalSpent': totalSpent,
      'balance': balance,
    };
  }

  PersonModel copyWith({
    String? id,
    String? name,
    double? totalReceived,
    double? totalSpent,
    double? balance,
  }) {
    return PersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      totalReceived: totalReceived ?? this.totalReceived,
      totalSpent: totalSpent ?? this.totalSpent,
      balance: balance ?? this.balance,
    );
  }
}
