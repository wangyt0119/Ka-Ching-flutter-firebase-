import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'pending_invitations_widget.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => isLoading = false);
        return;
      }
      
      // Get current user data
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final String currentUserName = userData['full_name'] ?? 'User';

      // Check if the email exists in Firebase Auth
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .limit(1)
          .get();
      
      final bool userExists = userQuery.docs.isNotEmpty;
      String? receiverId;
      
      if (userExists) {
        receiverId = userQuery.docs.first.id;
      }
      
      // Create invitation in Firestore
      await _firestore.collection('invitations').add({
        'sender_id': currentUser.uid,
        'sender_email': currentUser.email,
        'sender_name': currentUserName,
        'receiver_email': _emailController.text,
        'receiver_id': receiverId,
        'status': 'pending',
        'user_exists': userExists,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Only send email if user doesn't exist in the app
      if (!userExists) {
        final String emailBody = 'Hi! I would like to invite you to join Ka-Ching, my expense tracking app. Click here to join: https://your-app-link.com/invite/${currentUser.uid}';

        // Use share_plus to open the share sheet
        await Share.share(
          emailBody,
          subject: 'Join me on Ka-Ching!',
        );
      }
      
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userExists 
            ? 'Friend request sent' 
            : 'Invitation email sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending invitation: $e'))
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5A9C1),
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          // Invite Friend Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Color(0xFFF5A9C1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite Friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'Enter email address',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isLoading ? null : _sendInvitation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFFF5A9C1),
                      ),
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Invite'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Add the pending invitations widget
          PendingInvitationsWidget(),
          
          // Friends List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .collection('friends')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = snapshot.data?.docs ?? [];

                if (friends.isEmpty) {
                  return const Center(
                    child: Text(
                      'No friends yet. Invite some friends to get started!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final friendData = friend.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFFF5A9C1),
                        child: Text(
                          friendData['name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(friendData['name']),
                      subtitle: Text(friendData['email']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await _firestore
                                .collection('users')
                                .doc(_auth.currentUser?.uid)
                                .collection('friends')
                                .doc(friend.id)
                                .delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Friend removed successfully'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error removing friend: $e'),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
