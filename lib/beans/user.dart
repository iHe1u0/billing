class User {
  final int? id;
  final String username;
  final String password;
  final bool isAdmin;
  final bool isActive;
  final DateTime registerTime;
  final DateTime? expireTime;
  final String? note;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.isAdmin,
    required this.isActive,
    required this.registerTime,
    this.expireTime,
    this.note,
  });

  User copyWith({
    int? id,
    String? username,
    String? password,
    bool? isAdmin,
    bool? isActive,
    DateTime? registerTime,
    DateTime? expireTime,
    String? note,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
      registerTime: registerTime ?? this.registerTime,
      expireTime: expireTime ?? this.expireTime,
      note: note ?? this.note,
    );
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      isAdmin: map['isAdmin'] == 1,
      isActive: map['isActive'] == 1,
      registerTime: DateTime.parse(map['registerTime']),
      expireTime: map['expireTime'] != null ? DateTime.parse(map['expireTime']) : null,
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'isAdmin': isAdmin ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'registerTime': registerTime.toIso8601String(),
      'expireTime': expireTime?.toIso8601String(),
      'note': note,
    };
  }
}
