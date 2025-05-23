class UserProfile {
  static final UserProfile _instance = UserProfile._internal();
  factory UserProfile() => _instance;
  UserProfile._internal();

  String _userName = 'Test user';

  String get userName => _userName;

  void updateUserName(String name) {
    _userName = name;
  }
}
