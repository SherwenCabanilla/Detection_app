import 'package:flutter/material.dart';
import 'home_page.dart';
import 'register_page.dart';
import '../expert/expert_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:hive/hive.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _hasValidated = false;
  Map<String, String?> _fieldErrors = {};

  // Store verification codes in memory (for testing)
  final Map<String, Map<String, dynamic>> _verificationCodes = {};

  Future<void> _sendVerificationEmail(String email, String code) async {
    try {
      // Configure your email settings here
      // You can use Gmail, Outlook, or any SMTP server

      // For Gmail (you'll need to enable "Less secure app access" or use App Password)
      final smtpServer = gmail('your-email@gmail.com', 'your-app-password');

      // For Outlook
      // final smtpServer = SmtpServer('smtp-mail.outlook.com', username: 'your-email@outlook.com', password: 'your-password');

      // Create the email message
      final message =
          Message()
            ..from = Address('your-email@gmail.com', 'MangoSense App')
            ..recipients.add(email)
            ..subject = 'Password Reset Verification Code'
            ..html = '''
          <h2>Password Reset Verification</h2>
          <p>You requested a password reset for your MangoSense account.</p>
          <p>Your verification code is: <strong style="font-size: 24px; color: #4CAF50;">$code</strong></p>
          <p>This code will expire in 15 minutes.</p>
          <p>If you didn't request this, please ignore this email.</p>
          <br>
          <p>Best regards,<br>MangoSense Team</p>
        ''';

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } catch (e) {
      print('Error sending email: $e');
      // For now, we'll show the code in console for testing
      print('Verification code for $email: $code');
      throw Exception(
        'Failed to send verification email. Please check your email settings.',
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User cancelled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          // User exists, proceed with normal login flow
          final data = userDoc.data() as Map<String, dynamic>;
          final role = data['role'];
          final status = data['status'];

          if (status != 'active') {
            // Sign out from Firebase Auth and Google Sign-In
            await FirebaseAuth.instance.signOut();
            await _googleSignIn.signOut();

            setState(() {
              _isLoading = false;
            });

            String roleText = role == 'expert' ? 'expert' : 'farmer';
            String statusText = status ?? 'inactive';
            String statusMessage = '';

            // Create friendly status messages
            switch (statusText) {
              case 'pending':
                statusMessage =
                    'Your $roleText account is pending approval. You will receive an email notification once your account is approved by an administrator.';
                break;
              case 'rejected':
              case 'declined':
                statusMessage =
                    'Your $roleText account has been declined. Please contact support for more information.';
                break;
              case 'suspended':
              case 'banned':
                statusMessage =
                    'Your $roleText account has been suspended. Please contact support for assistance.';
                break;
              default:
                statusMessage =
                    'Your $roleText account is currently $statusText. Please contact support for assistance.';
            }

            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          statusText == 'pending'
                              ? Icons.pending_outlined
                              : Icons.warning_amber_rounded,
                          color:
                              statusText == 'pending'
                                  ? Colors.orange
                                  : Colors.red,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            statusText == 'pending'
                                ? 'Account Pending Approval'
                                : 'Account Not Active',
                            style: TextStyle(
                              color:
                                  statusText == 'pending'
                                      ? Colors.orange
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      statusMessage,
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
            );
            return;
          }

          // Save login state and user info to Hive
          final userBox = await Hive.openBox('userBox');
          await userBox.put('isLoggedIn', true);
          await userBox.put('userProfile', {
            'fullName': data['fullName'] ?? user.displayName ?? '',
            'email': data['email'] ?? user.email ?? '',
            'phoneNumber': data['phoneNumber'] ?? '',
            'address': data['address'] ?? '',
            'role': data['role'] ?? '',
            'imageProfile': data['imageProfile'] ?? user.photoURL ?? '',
            'userId': user.uid,
          });

          // Persist FCM token for notifications
          try {
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({'fcmToken': token}, SetOptions(merge: true));
            }
          } catch (_) {}

          // Navigate based on role
          if (role == 'expert') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ExpertDashboard()),
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          }
        } else {
          // User does not exist in Firestore - account not registered
          // Delete the Firebase Auth account that was just created
          try {
            await user.delete();
          } catch (e) {
            // If deletion fails, try to sign out as fallback
            await FirebaseAuth.instance.signOut();
          }

          // Sign out from Google Sign-In
          await _googleSignIn.signOut();

          setState(() {
            _isLoading = false;
          });

          // Show professional message that account is not registered
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Account Not Registered',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'This Google account is not yet registered in our system. Please register first using the registration form before signing in with Google.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
          );
          return;
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Google Sign-In failed. Please try again.';
      if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Sign-in was cancelled.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleLogin() async {
    setState(() {
      _hasValidated = true;
      _fieldErrors = {
        'email':
            _emailController.text.trim().isEmpty
                ? 'Please enter your email'
                : null,
        'password':
            _passwordController.text.trim().isEmpty
                ? 'Please enter your password'
                : null,
      };
    });

    if (_fieldErrors.values.any((error) => error != null && error.isNotEmpty)) {
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // First, check if the email exists in Firestore
        final usersQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();

        if (usersQuery.docs.isEmpty) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Email address "$email" is not registered. Please check your email or create a new account.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        // Email exists, now try to sign in
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final user = userCredential.user;
        if (user != null) {
          // Fetch user profile from Firestore
          DocumentSnapshot userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            final role = data['role'];
            final status = data['status'];

            // Debug: Print user data to console
            print('User data: $data');
            print('Role: $role, Status: $status');

            if (status != 'active') {
              setState(() {
                _isLoading = false;
              });
              String roleText = role == 'expert' ? 'expert' : 'farmer';
              String statusText = status ?? 'inactive';
              String statusMessage = '';

              // Create friendly status messages
              switch (statusText) {
                case 'pending':
                  statusMessage =
                      'Your $roleText account is pending approval. You will receive an email notification once your account is approved by an administrator.';
                  break;
                case 'rejected':
                case 'declined':
                  statusMessage =
                      'Your $roleText account has been declined. Please contact support for more information.';
                  break;
                case 'suspended':
                case 'banned':
                  statusMessage =
                      'Your $roleText account has been suspended. Please contact support for assistance.';
                  break;
                default:
                  statusMessage =
                      'Your $roleText account is currently $statusText. Please contact support for assistance.';
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(statusMessage),
                  backgroundColor:
                      statusText == 'pending' ? Colors.orange : Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (role == 'farmer') {
              // Ensure FCM token is saved so server can notify
              try {
                final token = await FirebaseMessaging.instance.getToken();
                if (token != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'fcmToken': token}, SetOptions(merge: true));
                }
              } catch (_) {}
              // Save login state and user info to Hive
              final userBox = await Hive.openBox('userBox');
              await userBox.put('isLoggedIn', true);
              await userBox.put('userProfile', {
                'fullName': data['fullName'] ?? '',
                'email': data['email'] ?? '',
                'phoneNumber': data['phoneNumber'] ?? '',
                'address': data['address'] ?? '',
                'role': data['role'] ?? '',
                'imageProfile': data['imageProfile'] ?? '',
                'userId': user.uid,
              });
              // Navigate to HomePage for farmer
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
              );
            } else if (role == 'expert') {
              // Ensure FCM token is saved for expert too
              try {
                final token = await FirebaseMessaging.instance.getToken();
                if (token != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'fcmToken': token}, SetOptions(merge: true));
                }
              } catch (_) {}
              // Save login state and expert info to Hive
              final userBox = await Hive.openBox('userBox');
              await userBox.put('isLoggedIn', true);
              await userBox.put('userProfile', {
                'fullName': data['fullName'] ?? '',
                'email': data['email'] ?? '',
                'phoneNumber': data['phoneNumber'] ?? '',
                'address': data['address'] ?? '',
                'role': data['role'] ?? '',
                'imageProfile': data['imageProfile'] ?? '',
                'userId': user.uid,
              });
              // Navigate to ExpertDashboard for expert
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpertDashboard(),
                ),
              );
            } else if (role == 'admin') {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Admin accounts should use the admin login portal.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            } else {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Unknown user role: ${role ?? 'undefined'}. Please contact support.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'User profile not found. Please contact support.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        String message;
        Color backgroundColor;

        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential':
          case 'INVALID_LOGIN_CREDENTIALS':
            message =
                'Incorrect email or password. Please check your credentials and try again.';
            backgroundColor = Colors.red;
            break;
          case 'user-not-found':
            message =
                'Email address not found. Please check your email or create a new account.';
            backgroundColor = Colors.orange;
            break;
          case 'invalid-email':
            message = 'Please enter a valid email address.';
            backgroundColor = Colors.orange;
            break;
          case 'user-disabled':
            message = 'This account has been disabled. Please contact support.';
            backgroundColor = Colors.red;
            break;
          case 'too-many-requests':
            message =
                'Too many failed login attempts. Please try again later or reset your password.';
            backgroundColor = Colors.orange;
            break;
          case 'network-request-failed':
            message =
                'Network error. Please check your internet connection and try again.';
            backgroundColor = Colors.orange;
            break;
          case 'operation-not-allowed':
            message =
                'Email/password sign-in is not enabled. Please contact support.';
            backgroundColor = Colors.red;
            break;
          case 'weak-password':
            message =
                'Password is too weak. Please choose a stronger password.';
            backgroundColor = Colors.orange;
            break;
          default:
            // Show the actual error code for debugging purposes
            message =
                'Login failed: ${e.code}. Please try again or contact support.';
            backgroundColor = Colors.red;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Logo and App Name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              'assets/applogo_header.png',
                              width: 56,
                              height: 56,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Mango',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Sense',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Welcome Text
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Log in to your account now',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    // Email Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const ValueKey('textfield_email'),
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            if (_hasValidated) {
                              setState(() {
                                _fieldErrors['email'] =
                                    value.trim().isEmpty
                                        ? 'Please enter your email'
                                        : null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor:
                                (_hasValidated && _fieldErrors['email'] != null)
                                    ? Colors.redAccent.withOpacity(0.1)
                                    : Colors.transparent,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    (_hasValidated &&
                                            _fieldErrors['email'] != null)
                                        ? Colors.redAccent
                                        : Colors.white70,
                                width:
                                    (_hasValidated &&
                                            _fieldErrors['email'] != null)
                                        ? 1.5
                                        : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    (_hasValidated &&
                                            _fieldErrors['email'] != null)
                                        ? Colors.redAccent
                                        : Colors.white,
                                width:
                                    (_hasValidated &&
                                            _fieldErrors['email'] != null)
                                        ? 1.5
                                        : 1,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.email,
                              color: Colors.white70,
                            ),
                            errorStyle: const TextStyle(height: 0, fontSize: 0),
                          ),
                        ),
                        if (_hasValidated &&
                            _fieldErrors['email'] != null &&
                            _fieldErrors['email']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 6,
                              right: 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _fieldErrors['email']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const ValueKey('textfield_password'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            if (_hasValidated) {
                              setState(() {
                                _fieldErrors['password'] =
                                    value.trim().isEmpty
                                        ? 'Please enter your password'
                                        : null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor:
                                (_hasValidated &&
                                        _fieldErrors['password'] != null)
                                    ? Colors.redAccent.withOpacity(0.1)
                                    : Colors.transparent,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    (_hasValidated &&
                                            _fieldErrors['password'] != null)
                                        ? Colors.redAccent
                                        : Colors.white70,
                                width:
                                    (_hasValidated &&
                                            _fieldErrors['password'] != null)
                                        ? 1.5
                                        : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    (_hasValidated &&
                                            _fieldErrors['password'] != null)
                                        ? Colors.redAccent
                                        : Colors.white,
                                width:
                                    (_hasValidated &&
                                            _fieldErrors['password'] != null)
                                        ? 1.5
                                        : 1,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.white70,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            errorStyle: const TextStyle(height: 0, fontSize: 0),
                          ),
                        ),
                        if (_hasValidated &&
                            _fieldErrors['password'] != null &&
                            _fieldErrors['password']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 6,
                              right: 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _fieldErrors['password']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(context),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Image.asset(
                          'assets/google-icon-1.png',
                          width: 24,
                          height: 24,
                        ),
                        label:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white70)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Guest Mode Button

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Create here',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Admin login removed (migrated to web)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
    final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: errorNotifier,
                    builder:
                        (context, error, child) =>
                            error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    error,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isLoadingNotifier,
                      builder:
                          (context, isLoading, child) => ElevatedButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : () async {
                                      final email = emailController.text.trim();

                                      if (email.isEmpty) {
                                        errorNotifier.value =
                                            'Please enter your email address.';
                                        return;
                                      }

                                      if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      ).hasMatch(email)) {
                                        errorNotifier.value =
                                            'Please enter a valid email address.';
                                        return;
                                      }

                                      isLoadingNotifier.value = true;
                                      errorNotifier.value = null;

                                      try {
                                        await FirebaseAuth.instance
                                            .sendPasswordResetEmail(
                                              email: email,
                                            );

                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Password reset link sent to $email',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } on FirebaseAuthException catch (e) {
                                        String errorMessage =
                                            'An error occurred while sending reset email.';
                                        if (e.code == 'user-not-found') {
                                          errorMessage =
                                              'No account found with this email address.';
                                        } else if (e.code == 'invalid-email') {
                                          errorMessage =
                                              'Please enter a valid email address.';
                                        } else if (e.code ==
                                            'too-many-requests') {
                                          errorMessage =
                                              'Too many requests. Please try again later.';
                                        }
                                        errorNotifier.value = errorMessage;
                                      } catch (e) {
                                        errorNotifier.value =
                                            'An unexpected error occurred.';
                                      } finally {
                                        isLoadingNotifier.value = false;
                                      }
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Send Reset Link',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
