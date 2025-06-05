import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add this

class TransactionDetailsScreen extends StatelessWidget {
  final String activity_id;
  final Map<String, dynamic> activityData;
  final String ownerUid;
  const TransactionDetailsScreen({
    Key? key,
    required this.activity_id,
    required this.activityData,
    required this.ownerUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activityName = activityData['name'] ?? 'Activity';

    // Get current Firebase user
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions - $activityName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .collection('activities')
            .doc(activity_id)
            .collection('transactions')
            .orderBy('timestamp', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          final transactions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final data = transactions[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled';
              final amount = data['amount'] ?? 0;
              final dateStr = data['date']?.toString();


              return ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(title),
                subtitle: Text(dateStr ?? 'No date'),
                trailing: Text('RM ${amount.toStringAsFixed(2)}'),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
