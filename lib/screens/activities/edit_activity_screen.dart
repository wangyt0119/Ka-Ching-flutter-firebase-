import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../home/user_home.dart';


class EditActivityScreen extends StatefulWidget {
  final Map<String, dynamic> activityData;

  const EditActivityScreen({super.key, required this.activityData});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  String _userEmail = '';
  String _userName = '';
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activityData['name']);
    _descriptionController = TextEditingController(text: widget.activityData['description']);
    _getCurrentUser().then((_) {
      _loadFriends();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Activity'),
      content: const Text('Are you sure you want to delete this activity?'),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await _deleteActivity(); // Perform deletion
          },
        ),
      ],
    ),
  );
}

  Future<void> _deleteActivity() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      final activityRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .doc(widget.activityData['activity_id']);

      await activityRef.delete();

      // Navigate to UserHome directly (replace below with your actual UserHome route)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const UserHomePage()),
        (Route<dynamic> route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting activity: $e')),
      );
    }
  }
}



  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();

      _userEmail = user.email ?? '';
      _userName = data?['full_name'] ?? 'You';

      // Set current user as selected
      _selectedMembers.add({
        'id': user.uid,
        'name': _userName,
        'email': _userEmail,
        'selected': true,
      });

      // Include other selected members
      final List members = widget.activityData['members'];
      for (var member in members) {
        if (member['id'] != user.uid) {
          _selectedMembers.add({...member, 'selected': true});
        }
      }

      setState(() {});
    }
  }

  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();

      final List<Map<String, dynamic>> loadedFriends = [];

      for (var doc in friendsSnapshot.docs) {
        final friendData = doc.data();
        final isSelected = _selectedMembers.any((m) => m['id'] == doc.id);
        loadedFriends.add({
          'id': doc.id,
          'name': friendData['name'],
          'email': friendData['email'],
          'selected': isSelected,
        });
      }

      setState(() {
        _friends = loadedFriends;
      });
    }
  }

  Future<void> _updateActivity() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity name')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final activityRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('activities')
            .doc(widget.activityData['activity_id']);

        final members = _selectedMembers
            .where((m) => m['selected'] == true)
            .map((m) => {
                  'id': m['id'],
                  'name': m['name'],
                  'email': m['email'],
                })
            .toList();

        await activityRef.update({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'members': members,
        });

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating activity: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Activity'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
    IconButton(
      icon: const Icon(Icons.delete),
      onPressed: _confirmDelete,
    ),
  ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Activity Name',
                prefixIcon: const Icon(Icons.edit, color: Color(0xFFB19CD9)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            // Description input
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                prefixIcon: const Icon(Icons.description, color: Color(0xFFB19CD9)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Participants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.pink.shade200,
                child: Text(_userName.isNotEmpty ? _userName[0] : 'Y'),
              ),
              title: const Text('You'),
              subtitle: Text(_userEmail),
              trailing: const Icon(Icons.check_circle, color: Colors.pink),
            ),
            const Divider(),
            const Text('Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(friend['name'][0].toUpperCase()),
                  ),
                  title: Text(friend['name']),
                  subtitle: Text(friend['email']),
                  trailing: Checkbox(
                    value: friend['selected'],
                    activeColor: Color(0xFFB19CD9),
                    onChanged: (value) {
                      setState(() {
                        _friends[index]['selected'] = value!;
                        if (value) {
                          _selectedMembers.add(_friends[index]);
                        } else {
                          _selectedMembers.removeWhere((m) => m['id'] == friend['id']);
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
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _updateActivity,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('UPDATE ACTIVITY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
