import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth_gate.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String fullName = '';
  String email = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        final DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          setState(() {
            fullName = userDoc.get('full_name') ?? 'User';
            email = currentUser.email ?? 'No email';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        fullName = 'User';
        email = 'Error loading data';
        isLoading = false;
      });
      print('Error fetching user data: $e');
    }
  }

  // Logout function
  Future<void> _logout() async {
    await _auth.signOut();
    // Navigate back to AuthGate (login screen)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5A9C1),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => EditProfileScreen(currentName: fullName),
                ),
              ).then((updated) {
                if (updated == true) {
                  _fetchUserData();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Pink top portion with profile picture
          Container(
            color: Color(0xFFF5A9C1),
            height: 60,
            width: double.infinity,
          ),

          // Profile picture (overlapping)
          Transform.translate(
            offset: const Offset(0, -50),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFFF5A9C1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              width: 100,
              height: 100,
              child: Center(
                child: Text(
                  isLoading
                      ? ''
                      : fullName.isNotEmpty
                      ? fullName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Color(0xFF6A0DAD),
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // User info
          Transform.translate(
            offset: const Offset(0, -30),
            child:
                isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            color: Color(0xFF6A0DAD),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(thickness: 1),
          ),

          // Settings, Help, Currency, Logout options
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: _buildMenuOption(
              Icons.settings,
              'Settings',
              Colors.deepPurple,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen(),
                ),
              );
            },
            child: _buildMenuOption(
              Icons.help,
              'Help & Support',
              Colors.deepPurple,
            ),
          ),
          _buildCurrencyOption(),
          _buildLogoutOption(),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.currency_exchange, color: Colors.deepPurple, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Currency',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Currently: USD',
                style: TextStyle(color: Colors.deepPurple, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: _logout, // Add the logout functionality here
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent, size: 24),
            const SizedBox(width: 16),
            Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
