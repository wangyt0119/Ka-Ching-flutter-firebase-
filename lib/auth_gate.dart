import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_home.dart';
import 'user_home.dart';
import 'custom_register_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // Function to get home screen based on role
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
          // Show SignIn screen when not logged in
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
              GoogleProvider(clientId: "175995407076-tefkgm4be14ik8rl6h0t3v46t067shcq.apps.googleusercontent.com"),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('kaching.png'),
                ),
              );
            },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: action == AuthAction.signIn
                    ? const Text('Welcome to Ka-Ching, please sign in!')
                    : const Text('Welcome to Ka-Ching, please sign up!'),
              );
            },
            // Adding showAuthActionSwitch to hide the default register link
            showAuthActionSwitch: false,
            actions: [
              // Override the default actions
              AuthStateChangeAction<SignedIn>((context, state) {
                // Handle sign in
              }),
            ],
            footerBuilder: (context, action) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'By signing in, you agree to our terms and conditions.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomRegisterScreen(),
                        ),
                      );
                    },
                    child: const Text("Don't have an account? Register here"),
                  ),
                ],
              );
            },
          );
        }

        // When logged in: load role and redirect accordingly
        return FutureBuilder<Widget>(
          future: _getHomeScreenBasedOnRole(snapshot.data!),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (roleSnapshot.hasError) {
              return const Center(child: Text('Error loading user role'));
            } else {
              return roleSnapshot.data!;
            }
          },
        );
      },
    );
  }
}