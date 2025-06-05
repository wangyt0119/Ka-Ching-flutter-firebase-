import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../theme/app_theme.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Current user data
  String _userEmail = '';
  String _userName = '';

  // List of friends
  List<Map<String, dynamic>> _friends = [];

  // Selected friends for this activity (including current user)
  final List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Get current user info
  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data = doc.data();

      setState(() {
        _userEmail = user.email ?? '';
        _userName = data?['full_name'] ?? 'You';

        // Add current user to selected members by default
        _selectedMembers.add({
          'id': user.uid,
          'name': _userName,
          'email': _userEmail,
          'selected': true,
        });
      });
    }
  }

  // Load friends from Firestore
  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final friendsSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('friends')
                .get();

        if (friendsSnapshot.docs.isNotEmpty) {
          final List<Map<String, dynamic>> loadedFriends = [];

          for (var doc in friendsSnapshot.docs) {
            final friendData = doc.data();
            loadedFriends.add({
              'id': doc.id,
              'name': friendData['name'] ?? '',
              'email': friendData['email'] ?? '',
              'selected': false,
            });
          }

          setState(() {
            _friends = loadedFriends;
          });
        }
      } catch (e) {
        print('Error loading friends: $e');
      }
    }
  }

  // Create a new activity
Future<void> _createActivity() async {
  if (_nameController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter an activity name')),
    );
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      // Create a new document with auto-generated ID
      final activityRef =
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .doc();

      // Prepare members data
      final List<Map<String, dynamic>> members =
          _selectedMembers
              .where((member) => member['selected'] == true)
              .map(
                (member) => {
                  'id': member['id'],
                  'name': member['name'],
                  'email': member['email'],
                },
              )
              .toList();

      // Get the user's current currency
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final currentCurrency = currencyProvider.selectedCurrency.code;

      // Create activity document
      await activityRef.set({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'members': members,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid, // Store user ID for chart compatibility
        'createdByName': _userName, // Store full name for display purposes
        'activity_id': activityRef.id,
        'currency': currentCurrency, // Store the activity's base currency
      });

      // Navigate back and show success message
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity created successfully')),
      );
    } catch (e) {
      print('Error creating activity: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating activity: $e')));
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Activity',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Activity Name',
                prefixIcon: const Icon(
                  Icons.celebration,
                  color: Color(0xFFB19CD9),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFB19CD9),
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: const Icon(
                  Icons.description,
                  color: Color(0xFFB19CD9),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFB19CD9),
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Members Section
            const Text(
              'Participants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Select friends to include in this activity',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),

            const SizedBox(height: 16),

            // Current User (always included)
            if (_selectedMembers.isNotEmpty)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.pink.shade200,
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'Y',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: const Text('You'),
                subtitle: Text(_userEmail),
                trailing: const Icon(Icons.check_circle, color: Colors.pink),
              ),

            const Divider(height: 32),

            // Friends Section
            const Text(
              'Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Friends List
            if (_friends.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'You haven\'t added any friends yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        friend['name'].toString()[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(friend['name']),
                    subtitle: Text(friend['email']),
                    trailing: Checkbox(
                      activeColor: Color(0xFFB19CD9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      value: _friends[index]['selected'],
                      onChanged: (value) {
                        setState(() {
                          _friends[index]['selected'] = value;

                          // Update selected members list
                          if (value == true) {
                            _selectedMembers.add(_friends[index]);
                          } else {
                            _selectedMembers.removeWhere(
                              (member) => member['id'] == _friends[index]['id'],
                            );
                          }
                        });
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _createActivity,
              child: const Text(
                'CREATE ACTIVITY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
