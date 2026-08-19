import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper method to write or update user details in Cloud Firestore
  Future<void> _syncUserToFirestore(User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();

    if (!docSnapshot.exists) {
      // Initialize full profile schema for new users
      await userRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'photoURL': user.photoURL ?? '',
        'bytesUsed': 0,
        'storageQuotaBytes': 262144000, // Default 250MB
        'allowAi': false,               // AI access locked until manual admin review
        'gemini': {
          'enabled': false,
          'models': {
            'gemini-2.5-flash': false,
            'gemini-3.7-flash': false,
          },
        },
        'ksAi': {
          'enabled': false,
          'models': {},
        },
        'thirdPartyAi': {
          'enabled': false,
          'byokUnlocked': false,       // Controlled via $1 developer unlock
          'hasCustomKey': false,
          'activeProvider': '',
          'models': {},
        },
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } else {
      // Update metadata on login without overwriting existing storage usage or AI rules
      await userRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'photoURL': user.photoURL ?? '',
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both an email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;
      if (_isSignUp) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (userCredential.user != null) {
        await _syncUserToFirestore(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed.');
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '290351455994-0lvi5lmiu2f34vklmr6mor9esa73153e.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _syncUserToFirestore(userCredential.user!);
      }
    } catch (e) {
      _showError('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchLegalHelp() async {
    final Uri url = Uri.parse('https://ks-messaging-docs.ks-everything.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showError('Could not open Legal & Help documentation.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Create Account' : 'KS-Messaging Login'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleEmailAuth,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_isSignUp ? 'Create Account' : 'Sign In with Email'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Register"),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('OR', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _signInWithGoogle,
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: _launchLegalHelp,
                        child: const Text(
                          'Legal & Help',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            decoration: TextDecoration.underline,
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