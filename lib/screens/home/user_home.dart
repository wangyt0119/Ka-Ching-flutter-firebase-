import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../activities/add_activity_screen.dart';
import '../transactions/add_expense_screen.dart';
import '../profile/profile_screen.dart';
import '../activities/activity_detail_screen.dart';
import '../friends/friends_screen.dart';
import '../transactions/transactions_screen.dart';

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

  int _selectedIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();

      final activitySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .orderBy('createdAt', descending: true)
              .get();

      final loadedActivities =
          activitySnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

      setState(() {
        fullName = data?['full_name'] ?? 'User';
        youOwe = data?['you_owe']?.toDouble() ?? 0.0;
        youAreOwed = data?['you_are_owed']?.toDouble() ?? 0.0;
        totalBalance = youAreOwed - youOwe;
        activities = loadedActivities.cast<Map<String, dynamic>>();

        _screens.clear();
        _screens.addAll([
          _buildHomeBody(),
          const TransactionsScreen(),
          const FriendsScreen(),
          const ProfileScreen(),
        ]);
      });
    }
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hello, $fullName",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Balance Summary",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.attach_money,
                                color: Colors.grey,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text("USD", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "You owe",
                              style: TextStyle(
                                color: Color(0xFFD1A4F5),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "\$${youOwe.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: AppTheme.dividerColor,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "You are owed",
                              style: TextStyle(
                                color: Color(0xFFD1A4F5),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "\$${youAreOwed.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total balance",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "\$${totalBalance.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: totalBalance >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 35),
                    ),
                    onPressed: () {},
                    child: const Text("Settle Up"),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Activities",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddActivityScreen(),
                    ),
                  ).then((_) => _loadUserData());
                },
                child: const Text(
                  "+ New",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...activities.map((activity) {
            final title = activity['name'] ?? 'Untitled';
            final createdAt =
                (activity['createdAt'] as Timestamp?)
                    ?.toDate()
                    .toLocal()
                    .toString()
                    .split(' ')[0] ??
                '';
            final total = activity['total']?.toDouble() ?? 0.0;
            final status = activity['status'] ?? '';
            final amount = activity['amount']?.toDouble() ?? 0.0;
            final members =
                activity['members'] != null
                    ? (activity['members'] as List).length
                    : 1;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ActivityDetailsScreen(
                                  activityId: activity['id'],
                                ),
                          ),
                        );
                      },
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLightColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.hiking,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(createdAt), const SizedBox(height: 4)],
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "\$${total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Total spent",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD1A4F5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 16,
                          color: Color(0xFFD1A4F5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$members members",
                          style: const TextStyle(color: Color(0xFFD1A4F5)),
                        ),
                        const Spacer(),
                        status == 'owe'
                            ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 254, 213, 217),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "You owe \$${amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: Color(0xFFD1A4F5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                            : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 214, 244, 215),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "You get back \$${amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: Color(0xFFD1A4F5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar:
          _selectedIndex == 0
              ? AppBar(
                backgroundColor: Theme.of(context).primaryColor,
                title: const Text(
                  'Ka-Ching',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              )
              : null,

      body:
          _screens.isNotEmpty
              ? _screens[_selectedIndex]
              : const Center(child: CircularProgressIndicator()),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                backgroundColor: const Color.fromARGB(255, 237, 71, 137),
                onPressed: () {
                  if (activities.isNotEmpty) {
                    final firstActivity = activities.first;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => AddExpenseScreen(
                              activityId: firstActivity['id'],
                              activityName: firstActivity['name'] ?? 'Untitled',
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please create an activity first.'),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.add),
              )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.textSecondary,
        unselectedItemColor: AppTheme.primaryColor,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
