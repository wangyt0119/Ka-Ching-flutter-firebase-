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
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/currency_service.dart';
import '../../models/currency.dart';

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
  String selectedCurrencyCode = 'USD';
  Currency? selectedCurrency;

  int _selectedIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCurrency();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to currency changes and reload user data
    Provider.of<CurrencyProvider>(context).addListener(_onCurrencyChanged);
  }

  @override
  void dispose() {
    Provider.of<CurrencyProvider>(context, listen: false).removeListener(_onCurrencyChanged);
    super.dispose();
  }

  void _onCurrencyChanged() {
    _loadUserData();
  }

  Future<void> _loadCurrency() async {
    final currencyService = CurrencyService();
    final currency = await currencyService.getSelectedCurrency();
    setState(() {
      selectedCurrencyCode = currency.code;
      selectedCurrency = currency;
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final selectedCurrency = currencyProvider.selectedCurrency;
      double totalOwed = 0.0;
      double totalOwing = 0.0;
      final createdActivitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .get();
      final loadedActivities = createdActivitiesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['isCreator'] = true;
        data['ownerId'] = user.uid;
        return data;
      }).toList();
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == user.uid) continue;
        final activitiesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('activities')
            .get();
        for (var activityDoc in activitiesSnapshot.docs) {
          final activityData = activityDoc.data();
          final members = activityData['members'] as List<dynamic>? ?? [];
          bool isParticipant = false;
          for (var member in members) {
            if (member is Map<String, dynamic> && 
                (member['id'] == user.uid || 
                 member['email'] == user.email)) {
              isParticipant = true;
              break;
            }
          }
          if (isParticipant) {
            activityData['id'] = activityDoc.id;
            activityData['isCreator'] = false;
            activityData['ownerId'] = userDoc.id;
            loadedActivities.add(activityData);
          }
        }
      }
      // For each activity, recalculate the user's balance in the selected currency
      for (var activity in loadedActivities) {
        final activityId = activity['id'];
        final ownerId = activity['ownerId'];
        final activityMembers = activity['members'] as List<dynamic>? ?? [];
        Map<String, double> balances = {};
        for (var member in activityMembers) {
          final id = member is Map ? (member['id'] ?? member['email'] ?? member['name']) : member;
          balances[id] = 0.0;
        }
        // Fetch all transactions for this activity
        final transactionsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('activities')
            .doc(activityId)
            .collection('transactions')
            .get();
        final transactions = transactionsSnapshot.docs.map((doc) => doc.data()).toList();
        for (var transaction in transactions) {
          final paidBy = transaction['paid_by'] ?? '';
          final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
          final originalCurrency = transaction['currency'] ?? 'USD';
          final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
            (c) => c.code == originalCurrency,
            orElse: () => selectedCurrency,
          );
          final amount = currencyProvider.convertToSelectedCurrency(originalAmount, fromCurrency);
          final split = transaction['split'] ?? 'equally';
          final participants = List<String>.from(transaction['participants'] ?? []);
          if (transaction['is_settlement'] == true) {
            continue;
          }
          if (split == 'equally' && participants.isNotEmpty) {
            final sharePerPerson = amount / participants.length;
            balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
            for (var participant in participants) {
              balances[participant] = (balances[participant] ?? 0.0) - sharePerPerson;
            }
            balances[paidBy] = (balances[paidBy] ?? 0.0) - sharePerPerson;
          } else if (split == 'unequally' && transaction['shares'] != null) {
            final shares = Map<String, dynamic>.from(transaction['shares']);
            balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
            for (var participant in participants) {
              final shareOriginal = shares[participant]?.toDouble() ?? 0.0;
              final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
              balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
            }
            final payerShareOriginal = shares[paidBy]?.toDouble() ?? 0.0;
            final payerShareConverted = currencyProvider.convertToSelectedCurrency(payerShareOriginal, fromCurrency);
            balances[paidBy] = (balances[paidBy] ?? 0.0) - payerShareConverted;
          } else if (split == 'percentage' && transaction['shares'] != null) {
            final shares = Map<String, dynamic>.from(transaction['shares']);
            balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
            for (var participant in participants) {
              final percentage = shares[participant]?.toDouble() ?? 0.0;
              final shareOriginal = originalAmount * percentage / 100;
              final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
              balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
            }
            final payerPercentage = shares[paidBy]?.toDouble() ?? 0.0;
            final payerShareOriginal = originalAmount * payerPercentage / 100;
            final payerShareConverted = currencyProvider.convertToSelectedCurrency(payerShareOriginal, fromCurrency);
            balances[paidBy] = (balances[paidBy] ?? 0.0) - payerShareConverted;
          }
        }
        String userKey = '';
        if (balances.containsKey(user.uid ?? '')) {
          userKey = user.uid ?? '';
        } else if (balances.containsKey(user.email ?? '')) {
          userKey = user.email ?? '';
        }
        final userBalance = userKey.isNotEmpty ? (balances[userKey] ?? 0.0) : 0.0;
        if (userBalance > 0) {
          totalOwing += userBalance;
        } else if (userBalance < 0) {
          totalOwed += userBalance.abs();
        }
      }
      setState(() {
        fullName = data?['full_name'] ?? 'User';
        youOwe = totalOwing;
        youAreOwed = totalOwed;
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
      _loadCurrency();
    }
  }

  String _formatAmount(double amount) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    return currencyProvider.formatAmount(amount);
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
                      Text(
                        "Balance Summary",
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: _showCurrencyDialog,
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
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: Colors.grey,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(selectedCurrencyCode, style: TextStyle(color: Colors.grey)),
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
                            Text(
                              "You owe",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatAmount(youOwe),
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
                            Text(
                              "You are owed",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatAmount(youAreOwed),
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
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _formatAmount(totalBalance),
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
                    onPressed: _showSettleUpDialog,
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
            final total = activity['totalAmount']?.toDouble() ?? 0.0;
            final balances = Map<String, dynamic>.from(activity['balances'] ?? {});
            final userBalance = balances['You']?.toDouble() ?? 0.0;
            final members =
                activity['members'] != null
                    ? (activity['members'] as List).length
                    : 1;
            final status = userBalance < 0 ? 'owe' : 'get_back';
            final amount = userBalance.abs();

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
                            builder: (_) => ActivityDetailsScreen(
                              activityId: activity['id'],
                              ownerId: activity['isCreator'] ? null : activity['ownerId'],
                            ),
                          ),
                        ).then((_) => _loadUserData()); // Reload data when returning
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
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
                            _formatAmount(total),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Total spent",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "$members members",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        Spacer(),
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
                                "You owe ${_formatAmount(amount)}",
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
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
                                "You get back ${_formatAmount(amount)}",
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
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

  void _showCurrencyDialog() async {
    final currencyService = CurrencyService();
    final currencies = currencyService.getAllCurrencies();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              return ListTile(
                title: Text('${currency.name} (${currency.code})'),
                trailing: currency.code == selectedCurrencyCode
                    ? const Icon(Icons.check, color: Color(0xFFF5A9C1))
                    : null,
                onTap: () async {
                  await currencyService.setSelectedCurrency(currency);
                  setState(() {
                    selectedCurrencyCode = currency.code;
                    selectedCurrency = currency;
                  });
                  _loadUserData();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSettleUpDialog() async {
    // Step 1: Select activity
    if (activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No activities to settle.')),
      );
      return;
    }
    String? selectedActivityId;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Activity'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                title: Text(activity['name'] ?? 'Untitled'),
                onTap: () {
                  selectedActivityId = activity['id'];
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
    if (selectedActivityId == null) return;
    final selectedActivity = activities.firstWhere((a) => a['id'] == selectedActivityId);
    final balances = Map<String, dynamic>.from(selectedActivity['balances'] ?? {});
    // Step 2: Select user to settle with
    List<String> otherUsers = balances.keys.where((k) => k != 'You' && (balances[k] as num).abs() > 0).toList();
    if (otherUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No one to settle with in this activity.')),
      );
      return;
    }
    String? selectedUser;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select User to Settle With'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final user = otherUsers[index];
              final bal = balances[user]?.toDouble() ?? 0.0;
              final displayText = bal > 0
                  ? 'You owe $user ${_formatAmount(bal.abs())}'
                  : '$user owes you ${_formatAmount(bal.abs())}';
              return ListTile(
                title: Text(user),
                subtitle: Text(displayText),
                onTap: () {
                  selectedUser = user;
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
    if (selectedUser == null) return;
    final userBalance = balances[selectedUser]?.toDouble() ?? 0.0;
    final isPositive = userBalance > 0;
    final maxAmount = userBalance.abs();
    final TextEditingController amountController = TextEditingController(
      text: maxAmount.toStringAsFixed(2),
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Settlement Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPositive
                  ? 'You owe $selectedUser ${_formatAmount(maxAmount)}'
                  : '$selectedUser owes you ${_formatAmount(maxAmount)}',
            ),
            const SizedBox(height: 16),
            const Text('How much would you like to settle?'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: selectedCurrency?.symbol ?? ' 24',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter an amount between 0 and ${_formatAmount(maxAmount)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a positive amount')),
                );
                return;
              }
              if (amount > maxAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Amount cannot exceed ${_formatAmount(maxAmount)}')),
                );
                return;
              }
              Navigator.pop(context);
              _createSettlementTransaction(selectedActivity, selectedUser!, isPositive ? amount : -amount);
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSettlementTransaction(Map<String, dynamic> activity, String person, double balance) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final activityId = activity['id'];
        final ownerId = activity['isCreator'] ? user.uid : activity['ownerId'];
        // Create a settlement transaction in the selected activity
        final isPositive = balance >= 0;
        final settlement = {
          'title': isPositive ? '$person settled debt' : 'You settled debt with $person',
          'amount': balance.abs(),
          'currency': selectedCurrencyCode,
          'date': DateTime.now().toString().split(' ')[0],
          'description': 'Settlement transaction',
          'paid_by': isPositive ? person : 'You',
          'split': 'equally',
          'participants': [isPositive ? 'You' : person],
          'is_settlement': true,
          'timestamp': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('activities')
            .doc(activityId)
            .collection('transactions')
            .add(settlement);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement recorded successfully'),
          ),
        );
        _loadUserData();
      }
    } catch (e) {
      print('Error creating settlement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating settlement: $e'),
        ),
      );
    }
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
                      // Show a dialog to select which activity to add expense to
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Select Activity'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: activities.length,
                                itemBuilder: (context, index) {
                                  final activity = activities[index];
                                  return ListTile(
                                    title: Text(activity['name'] ?? 'Untitled'),
                                    onTap: () {
                                      Navigator.pop(context); // Close dialog
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddExpenseScreen(
                                            activityId: activity['id'],
                                            activityName: activity['name'] ?? 'Untitled',
                                            ownerId: activity['isCreator'] ? null : activity['ownerId'],
                                          ),
                                        ),
                                      ).then((_) => _loadUserData());
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
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
