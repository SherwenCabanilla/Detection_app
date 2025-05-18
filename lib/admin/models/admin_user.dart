class AdminUser {
  final String id;
  final String username;
  final String email;
  final String role;
  final DateTime lastLogin;

  AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.lastLogin,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'],
      lastLogin: DateTime.parse(json['lastLogin']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'lastLogin': lastLogin.toIso8601String(),
    };
  }
}
