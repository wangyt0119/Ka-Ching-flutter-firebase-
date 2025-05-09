import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../activities/add_activity_screen.dart';
import '../transactions/add_expense_screen.dart'; // Import AddExpenseScreen

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String fullName = '';
  double youOwe = 0;
  double youAreOwed = 0;
  double totalBalance = 0;

  List<Map<String, dynamic>> activities = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();

      final activitySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .get();

      final loadedActivities = activitySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include activityId
        return data;
      }).toList();

      setState(() {
        fullName = data?['full_name'] ?? 'User';
        youOwe = data?['you_owe']?.toDouble() ?? 0.0;
        youAreOwed = data?['you_are_owed']?.toDouble() ?? 0.0;
        totalBalance = youAreOwed - youOwe;
        activities = loadedActivities.cast<Map<String, dynamic>>();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade100,
        title: const Text("Ka-Ching", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello, $fullName", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),

            // Balance Summary Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("You owe", style: TextStyle(color: Colors.red)),
                        Text("You are owed", style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("\$${youOwe.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.red, fontSize: 18)),
                        Text("\$${youAreOwed.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.green, fontSize: 18)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total balance"),
                        Text(
                          "\$${totalBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: totalBalance >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade100,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {}, // TODO: handle settle up
                      child: const Text("Settle Up"),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            // Header row with "+ New" button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Your Activities", style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddActivityScreen()),
                    ).then((_) => _loadUserData());
                  },
                  child: const Text("+ New", style: TextStyle(color: Colors.purple)),
                )
              ],
            ),
            const SizedBox(height: 12),

            ...activities.map((activity) {
              final title = activity['name'] ?? 'Untitled';
              final date = activity['date'] ?? '';
              final total = activity['total']?.toDouble() ?? 0.0;
              final status = activity['status'] ?? '';
              final amount = activity['amount']?.toDouble() ?? 0.0;
              final members = activity['members'] != null ? (activity['members'] as List).length : 1;
              final activityId = activity['id'];

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.group, color: Colors.pinkAccent),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$date $members members"),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("\$${total.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (status == 'owe')
                        Chip(label: Text("You owe \$${amount.toStringAsFixed(2)}"),
                            backgroundColor: Colors.red.shade100)
                      else
                        Chip(label: Text("You get back \$${amount.toStringAsFixed(2)}"),
                            backgroundColor: Colors.green.shade100),
                    ],
                  ),
                  // onTap: () {
                  //   Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //       builder: (_) => AddExpenseScreen(
                  //         activityId: activityId,
                  //         activityName: title,
                  //       ),
                  //     ),
                  //   );
                  // },
                ),
              );
            }).toList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
      backgroundColor: const Color.fromARGB(255, 237, 71, 137),
      onPressed: () {
        if (activities.isNotEmpty) {
          // If at least one activity exists, navigate to the first one
          final firstActivity = activities.first;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                activityId: firstActivity['id'],
                activityName: firstActivity['name'] ?? 'Untitled',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please create an activity first.')),
          );
        }
      },
      child: const Icon(Icons.add),
    ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
