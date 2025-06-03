import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingInvitationsWidget extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PendingInvitationsWidget({Key? key}) : super(key: key);

  Future<void> _acceptInvitation(String invitationId, Map<String, dynamic> data) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get current user data
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data() ?? {};
    final String currentUserName = userData['full_name'] ?? 'User';
    
    // Create a batch to perform multiple operations
    final batch = _firestore.batch();
    
    // Update invitation status
    final invitationRef = _firestore.collection('invitations').doc(invitationId);
    batch.update(invitationRef, {'status': 'accepted'});
    
    // Add sender as friend to current user's friends collection
    final myFriendRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .doc(data['sender_id']);
        
    batch.set(myFriendRef, {
      'name': data['sender_name'] ?? data['sender_email'].split('@')[0],
      'email': data['sender_email'],
      'created_at': FieldValue.serverTimestamp(),
    });
    
    // Add current user as friend to sender's friends collection
    final theirFriendRef = _firestore
        .collection('users')
        .doc(data['sender_id'])
        .collection('friends')
        .doc(currentUser.uid);
        
    batch.set(theirFriendRef, {
      'name': currentUserName,
      'email': currentUser.email,
      'created_at': FieldValue.serverTimestamp(),
    });
    
    // Also add to the global friends collection for backward compatibility
    final globalMyFriendRef = _firestore.collection('friends').doc();
    batch.set(globalMyFriendRef, {
      'user_id': currentUser.uid,
      'friend_id': data['sender_id'],
      'friend_email': data['sender_email'],
      'friend_name': data['sender_name'] ?? data['sender_email'].split('@')[0],
      'created_at': FieldValue.serverTimestamp(),
    });
    
    final globalTheirFriendRef = _firestore.collection('friends').doc();
    batch.set(globalTheirFriendRef, {
      'user_id': data['sender_id'],
      'friend_id': currentUser.uid,
      'friend_email': currentUser.email,
      'friend_name': currentUserName,
      'created_at': FieldValue.serverTimestamp(),
    });
    
    // Commit the batch
    await batch.commit();
  }

  Future<void> _declineInvitation(String invitationId) async {
    await _firestore.collection('invitations').doc(invitationId).update({
      'status': 'declined'
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('invitations')
          .where('receiver_email', isEqualTo: _auth.currentUser?.email)
          .where('status', isEqualTo: 'pending')
          .where('user_exists', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final invitations = snapshot.data?.docs ?? [];
        
        if (invitations.isEmpty) {
          return const SizedBox();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Friend Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invitations.length,
                itemBuilder: (context, index) {
                  final invitation = invitations[index];
                  final data = invitation.data() as Map<String, dynamic>;
                  final senderName = data['sender_name'] ?? data['sender_email'].split('@')[0];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFFF5A9C1),
                        child: Text(
                          senderName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text('$senderName wants to be friends'),
                      subtitle: Text(data['sender_email']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            child: const Text('Accept', style: TextStyle(color: Colors.green)),
                            onPressed: () => _acceptInvitation(invitation.id, data),
                          ),
                          TextButton(
                            child: const Text('Decline', style: TextStyle(color: Colors.red)),
                            onPressed: () => _declineInvitation(invitation.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
