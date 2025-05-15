import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/home/admin_home.dart';
import 'screens/home/user_home.dart';
import 'screens/auth/custom_register_screen.dart';
import 'theme/app_theme.dart'; // Add this to access AppTheme

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHomeScreenBasedOnRole(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = doc.data()?['role'] ?? 'user';

      if (role == 'admin') {
        return const AdminHomePage();
      } else {
        return const UserHomePage();
      }
    } catch (e) {
      print('Error loading role: $e');
      return const Center(child: Text('Error loading user role'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
              GoogleProvider(
                clientId: "175995407076-tefkgm4be14ik8rl6h0t3v46t067shcq.apps.googleusercontent.com",
              ),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'kaching.png',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  action == AuthAction.signIn
                      ? 'Welcome to Ka-Ching, please sign in!'
                      : 'Welcome to Ka-Ching, please sign up!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            },
            showAuthActionSwitch: false,
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final screen = await _getHomeScreenBasedOnRole(user);
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => screen),
                    );
                  }
                }
              }),
            ],
            styles: const {
              EmailFormStyle(
                signInButtonVariant: ButtonVariant.filled,
              ),
            },
            footerBuilder: (context, action) {
  return Column(
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(
          'By signing in, you agree to our terms and conditions.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomRegisterScreen(),
                ),
              );
            },
            child: const Text(
              'Register',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ],
  );
},

          );
        }

        // If user is already signed in
        return FutureBuilder<Widget>(
          future: _getHomeScreenBasedOnRole(snapshot.data!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Failed to load home screen.'));
            } else {
              return snapshot.data!;
            }
          },
        );
      },
    );
  }
}
