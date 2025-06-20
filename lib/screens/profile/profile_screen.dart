import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth_gate.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';

import 'edit_profile_screen.dart';
import '../settings/settings_screen.dart';
import 'help_support_screen.dart';
import '../../services/currency_service.dart';
import '../help/help_screen.dart';

import 'dart:convert';
import 'dart:typed_data';

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
  Uint8List? profileImage;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

            if (userDoc.data() != null && userDoc.data() is Map<String, dynamic>) {
            final data = userDoc.data() as Map<String, dynamic>;
            final String? base64String = data['profile_image'];
            if (base64String != null && base64String.isNotEmpty) {
              profileImage = base64Decode(base64String);
            }
          }


            isLoading = false;
          });
        } else {
          // Create user document if it doesn't exist
          await _firestore.collection('users').doc(currentUser.uid).set({
            'full_name': currentUser.displayName ?? 'User',
            'email': currentUser.email,
            'currency': 'MYR',
            'profile_image': '',
            'created_at': FieldValue.serverTimestamp(),
          });
          setState(() {
            fullName = currentUser.displayName ?? 'User';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _updateProfile() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'full_name': _nameController.text,
        });
        setState(() {
          fullName = _nameController.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  Future<void> _updateCurrency(String newCurrency) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'currency': newCurrency,
        });
        final currencyService = CurrencyService();
        final currency = currencyService.getCurrencyByCode(newCurrency) ?? currencyService.getDefaultCurrency();
        final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
        await currencyProvider.setSelectedCurrency(currency);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Currency updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating currency: $e')));
    }
  }

  void _showEditProfileDialog() {
    _nameController.text = fullName;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile'),
            content: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _updateProfile();
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showCurrencyDialog() {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: CurrencyService.supportedCurrencies.length,
            itemBuilder: (context, index) {
              final currency = CurrencyService.supportedCurrencies.keys.elementAt(index);
              final currencyInfo = CurrencyService.supportedCurrencies[currency];
              return ListTile(
                title: Text(currencyInfo ?? currency),
                trailing: currency == currencyProvider.selectedCurrency.code
                    ? const Icon(Icons.check, color: Color(0xFFF5A9C1))
                    : null,
                onTap: () {
                  _updateCurrency(currency);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final selectedCurrency = currencyProvider.selectedCurrency.code;
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
              child: profileImage != null
                ? ClipOval(
                    child: Image.memory(
                      profileImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      isLoading
                          ? ''
                          : fullName.isNotEmpty
                              ? fullName[0].toUpperCase()
                              : 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(
              color: Color.fromARGB(255, 228, 207, 232),
              thickness: 2
              ),
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
              Theme.of(context).colorScheme.secondary,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
            child: _buildMenuOption(
              Icons.help,
              'Help & Support',
              Theme.of(context).colorScheme.secondary,
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
      child: GestureDetector(
        onTap: () {
          if (title == 'Settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          } else if (title == 'Help & Support') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpScreen()),
            );
          }
        },
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
      ),
    );
  }

  Widget _buildCurrencyOption() {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: _showCurrencyDialog,
        child: Row(
          children: [
            Icon(
              Icons.currency_exchange,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Currency',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Currently: ${currencyProvider.selectedCurrency.code}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: _logout,
        child: Row(
          children: [
            Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              'Logout',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
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
