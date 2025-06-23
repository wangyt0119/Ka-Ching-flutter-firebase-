import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../activities/add_activity_screen.dart';
import '../transactions/add_expense_screen.dart';
import '../profile/profile_screen.dart';
import '../activities/activity_det_scr.dart';
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

        // Initialize balances for all members using their actual IDs
        for (var member in activityMembers) {
          final id = member is Map ? (member['id'] ?? member['email'] ?? member['name']) : member;
          balances[id] = 0.0;
        }

        // Get all user identifiers for the current user
        final userKeys = [
          user.uid,
          user.email,
          user.displayName,
          'You'
        ].where((key) => key != null && key.isNotEmpty).toList().cast<String>();

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
          // Skip settlement transactions when calculating balances
          if (transaction['is_settlement'] == true) continue;
          
          final paidBy = transaction['paid_by'] ?? '';
          final paidById = transaction['paid_by_id'] ?? '';
          final originalAmount = transaction['amount']?.toDouble() ?? 0.0;
          final originalCurrency = transaction['currency'] ?? 'USD';
          final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
            (c) => c.code == originalCurrency,
            orElse: () => selectedCurrency,
          );
          final amount = currencyProvider.convertToSelectedCurrency(originalAmount, fromCurrency);
          final split = transaction['split'] ?? 'equally';
          final participants = List<String>.from(transaction['participants'] ?? []);

          // Determine if current user is the payer
          final isCurrentUserPayer = userKeys.contains(paidBy) || userKeys.contains(paidById);
          
          if (split == 'equally' && participants.isNotEmpty) {
            final sharePerPerson = amount / participants.length;
            balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
            for (var participant in participants) {
              balances[participant] = (balances[participant] ?? 0.0) - sharePerPerson;
            }
            // Note: paidBy is already included in participants loop above, so no need to deduct again
          } else if (split == 'unequally' && transaction['shares'] != null) {
            final shares = Map<String, dynamic>.from(transaction['shares']);
            balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
            for (var participant in participants) {
              final shareOriginal = shares[participant]?.toDouble() ?? 0.0;
              final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
              balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
            }
            // Note: paidBy is already included in participants loop above, so no need to deduct again
          } else if (split == 'percentage' && transaction['shares'] != null) {
            final shares = Map<String, dynamic>.from(transaction['shares']);
            balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;
            for (var participant in participants) {
              final percentage = shares[participant]?.toDouble() ?? 0.0;
              final shareOriginal = originalAmount * percentage / 100;
              final shareConverted = currencyProvider.convertToSelectedCurrency(shareOriginal, fromCurrency);
              balances[participant] = (balances[participant] ?? 0.0) - shareConverted;
            }
            // Note: paidBy is already included in participants loop above, so no need to deduct again
          }
        }
        
        // After processing all transactions, consolidate user's balance
        double consolidatedUserBalance = 0.0;
        for (String key in userKeys) {
          if (balances.containsKey(key)) {
            consolidatedUserBalance += balances[key] ?? 0.0;
            balances.remove(key);
          }
        }
        
        // Store the consolidated balance for the current user
        activity['userBalance'] = consolidatedUserBalance;
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
                        "Activities Summary",
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.hiking,
                                color: AppTheme.primaryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${activities.length}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              "Total Activities",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 80,
                        width: 1,
                        color: AppTheme.dividerColor,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.receipt,
                                color: AppTheme.accentColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${activities.where((a) => a['isCreator'] == true).length}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor,
                              ),
                            ),
                            Text(
                              "Created by You",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 35),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddActivityScreen(),
                        ),
                      ).then((_) => _loadUserData());
                    },
                    child: const Text("Create New Activity"),
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
            final user = FirebaseAuth.instance.currentUser;
            final title = activity['name'] ?? 'Untitled';
            final createdAt =
                (activity['createdAt'] as Timestamp?)
                    ?.toDate()
                    .toLocal()
                    .toString()
                    .split(' ')[0] ??
                '';
            // The stored totalAmount is in USD base currency, convert to display currency
            final totalInUSD = activity['totalAmount']?.toDouble() ?? 0.0;
            final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
            final baseCurrencyObj = currencyProvider.availableCurrencies.firstWhere(
              (c) => c.code == 'USD',
              orElse: () => currencyProvider.selectedCurrency,
            );
            final total = currencyProvider.convertCurrency(totalInUSD, baseCurrencyObj, currencyProvider.selectedCurrency);
            final balances = Map<String, dynamic>.from(activity['balances'] ?? {});

            // Find user balance using multiple possible keys
            double userBalance = 0.0;
            if (balances.containsKey('You')) {
              userBalance = balances['You']?.toDouble() ?? 0.0;
            } else if (user != null && balances.containsKey(user.uid)) {
              userBalance = balances[user.uid]?.toDouble() ?? 0.0;
            } else if (user != null && balances.containsKey(user.email)) {
              userBalance = balances[user.email]?.toDouble() ?? 0.0;
            } else if (user != null) {
              // Try to find by matching member data
              final activityMembers = activity['members'] as List<dynamic>? ?? [];
              for (var member in activityMembers) {
                if (member is Map<String, dynamic>) {
                  if (member['id'] == user.uid || member['email'] == user.email) {
                    final memberKey = member['id'] ?? member['email'] ?? member['name'];
                    if (balances.containsKey(memberKey)) {
                      userBalance = balances[memberKey]?.toDouble() ?? 0.0;
                      break;
                    }
                  }
                }
              }
            }
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
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(16), // Increased padding here
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityDetailScreen(
                  activityId: activity['id'],
                  ownerId: activity['isCreator'] ? null : activity['ownerId'],
                  title: activity['name'],
                ),
              ),
            ).then((_) => _loadUserData());
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(createdAt),
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
        const SizedBox(height: 12), // More space before divider
        const Divider(
          color: Color.fromARGB(255, 228, 207, 232),
          thickness: 2,
        ),
        const SizedBox(height: 12), // More space after divider
        Row(
          children: [
            Icon(
              Icons.people,
              size: 16,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              "$members members",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'owe'
                    ? const Color.fromARGB(255, 254, 213, 217)
                    : const Color.fromARGB(255, 214, 244, 215),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status == 'owe'
                    ? "You owe ${_formatAmount(amount)}"
                    : "You get back ${_formatAmount(amount)}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
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
          const SizedBox(height: 60),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No activities to settle.')),
        );
      }
      return;
    }
    String? selectedActivityId;
    if (mounted) {
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
    }
    if (selectedActivityId == null) return;
    final selectedActivity = activities.firstWhere((a) => a['id'] == selectedActivityId);
    final balances = Map<String, dynamic>.from(selectedActivity['balances'] ?? {});
    // Step 2: Select user to settle with
    List<String> otherUsers = balances.keys.where((k) => k != 'You' && (balances[k] as num).abs() > 0).toList();
    if (otherUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No one to settle with in this activity.')),
        );
      }
      return;
    }
    String? selectedUser;
    if (mounted) {
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
    }
    if (selectedUser == null) return;
    final userBalance = balances[selectedUser]?.toDouble() ?? 0.0;
    final isPositive = userBalance > 0;
    final maxAmount = userBalance.abs();
    final TextEditingController amountController = TextEditingController(
      text: maxAmount.toStringAsFixed(2),
    );
    if (mounted) {
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
  }

  Future<void> _createSettlementTransaction(Map<String, dynamic> activity, String person, double balance) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final activityId = activity['id'];
        final ownerId = activity['isCreator'] ? user.uid : activity['ownerId'];
        final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

        // Get the activity's original currency
        final activityCurrency = activity['currency'] ?? 'USD';
        final activityCurrencyObj = currencyProvider.getCurrencyByCode(activityCurrency) ??
                                   currencyProvider.selectedCurrency;

        // Convert the settlement amount to the activity's currency
        final settlementAmountInActivityCurrency = currencyProvider.convertCurrency(
          balance.abs(),
          currencyProvider.selectedCurrency,
          activityCurrencyObj
        );

        // Create a settlement transaction in the selected activity
        final isPositive = balance >= 0;

        // Use the actual user ID instead of "You" for consistency with balance calculations
        final currentUserKey = user.uid;

        final settlement = {
          'title': isPositive ? 'You settled debt with $person' : '$person settled debt with you',
          'amount': settlementAmountInActivityCurrency,
          'currency': activityCurrency,
          'date': DateTime.now().toString().split(' ')[0],
          'description': 'Settlement transaction',
          'paid_by': isPositive ? currentUserKey : person,
          'split': 'settlement', // Use a special split type for settlements
          'participants': [person], // Only the other person participates in settlement
          'settlement_amount': settlementAmountInActivityCurrency,
          'settlement_from': isPositive ? currentUserKey : person,
          'settlement_to': isPositive ? person : currentUserKey,
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settlement recorded successfully'),
            ),
          );
        }
        _loadUserData();
      }
    } catch (e) {
      debugPrint('Error creating settlement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating settlement: $e'),
          ),
        );
      }
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






