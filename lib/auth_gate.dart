import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/home/admin_home.dart';
import 'screens/home/user_home.dart';
import 'screens/auth/custom_register_screen.dart';
import 'screens/auth/custom_login_screen.dart';
import 'theme/app_theme.dart'; // Add this to access AppTheme

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHomeScreenBasedOnRole(User user) async {
    try {
      final doc =
          await FirebaseFirestore.instance
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
          return const CustomLoginScreen();
        }
        return FutureBuilder<Widget>(
          future: _getHomeScreenBasedOnRole(snapshot.data!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Failed to load home screen.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            } else {
              return snapshot.data!;
            }
          },
        );
      },
    );
  }
}
