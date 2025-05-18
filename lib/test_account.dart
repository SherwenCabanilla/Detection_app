// This file contains test account credentials for development and testing purposes only.
// DO NOT use these credentials in production.

class TestAccounts {
  // Expert account credentials
  static String expertEmail = 'expert';
  static String expertPassword = 'expert';

  // User/Farmer account credentials
  static const String userEmail = 'user';
  static const String userPassword = 'user';

  // Admin account credentials
  static const String adminEmail = 'admin';
  static const String adminPassword = 'admin';

  // Helper method to check if credentials are valid
  static String? validateCredentials(String email, String password) {
    if (email == adminEmail && password == adminPassword) {
      return 'admin';
    } else if (email == expertEmail && password == expertPassword) {
      return 'expert';
    } else if (email == userEmail && password == userPassword) {
      return 'user';
    }
    return null;
  }

  // Helper method to check if email is an expert account
  static bool isExpertEmail(String email) {
    return email == expertEmail;
  }

  // Helper method to check if email is a user account
  static bool isUserEmail(String email) {
    return email == userEmail;
  }

  static void setExpertCredentials(String email, String password) {
    expertEmail = email;
    expertPassword = password;
  }
}
