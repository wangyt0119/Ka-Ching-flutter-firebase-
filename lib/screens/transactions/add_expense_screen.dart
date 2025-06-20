import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/currency_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final String activityId;
  final String? activityName;
  final String? ownerId;

  // Constructor that accepts both old and new parameter formats
  const AddExpenseScreen({
    super.key, 
    required this.activityId,
    this.activityName,
    this.ownerId,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedActivityId;
  String? selectedActivityName;
  List<Map<String, dynamic>> userActivities = [];

  String selectedCurrency = 'MYR'; // default
  DateTime selectedDate = DateTime.now();
  File? _receiptImage;
  String? _base64Image;

  String splitMethod = 'equally';
  String? paidBy = 'You';

  // Category selection
  String selectedCategory = 'Food';
  final List<String> categories = [
    'Food', 
    'Beverage', 
    'Entertainment', 
    'Transportation', 
    'Shopping', 
    'Travel', 
    'Utilities', 
    'Other'
  ];

  List<String> allParticipants = [];
  Map<String, bool> selectedParticipants = {};

  Map<String, double> customShares = {};
  Map<String, TextEditingController> shareControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _loadUserCurrency();
  }

  Future<void> _fetchActivities() async {
    final user = _auth.currentUser!;
    final List<Map<String, dynamic>> allActivities = [];

    // First, get activities created by the current user
    final ownActivitiesSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .get();

    final ownActivities = await Future.wait(ownActivitiesSnapshot.docs.map((doc) async {
      final activityData = doc.data();
      
      // Get the latest friends list
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();
          
      final friends = friendsSnapshot.docs.map((friendDoc) {
        return friendDoc.data()['name'] as String;
      }).toList();
      
      return {
        'id': doc.id,
        'name': activityData['name'] ?? 'Unnamed Activity',
        'friends': friends,
        'ownerId': user.uid,
        'isCreator': true,
      };
    }).toList());

    allActivities.addAll(ownActivities);

    // Then, get activities where user is a participant (but not creator)
    final usersSnapshot = await _firestore
        .collection('users')
        .get();

    for (var userDoc in usersSnapshot.docs) {
      if (userDoc.id == user.uid) continue;
      
      final activitiesSnapshot = await _firestore
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
          // Get the latest friends list for this activity
          final friendsSnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('friends')
              .get();
              
          final friends = friendsSnapshot.docs.map((friendDoc) {
            return friendDoc.data()['name'] as String;
          }).toList();
          
          allActivities.add({
            'id': activityDoc.id,
            'name': activityData['name'] ?? 'Unnamed Activity',
            'friends': friends,
            'ownerId': userDoc.id,
            'isCreator': false,
          });
        }
      }
    }

    setState(() {
      userActivities = allActivities;
      if (allActivities.isNotEmpty) {
        // If activityId was provided, select that activity
        if (widget.activityId.isNotEmpty) {
          final selectedActivity = allActivities.firstWhere(
            (activity) => activity['id'] == widget.activityId,
            orElse: () => allActivities[0],
          );
          selectedActivityId = selectedActivity['id'];
          selectedActivityName = selectedActivity['name'];
          _setParticipants(selectedActivity['friends']);
        } else {
          selectedActivityId = allActivities[0]['id'];
          selectedActivityName = allActivities[0]['name'];
          _setParticipants(allActivities[0]['friends']);
        }
      }
    });
  }

  Future<void> _loadUserCurrency() async {
    final currencyService = CurrencyService();
    final currency = await currencyService.getSelectedCurrency();
    setState(() {
      selectedCurrency = currency.code;
    });
  }

  Future<void> _updateCurrency(String newCurrency) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'currency': newCurrency,
        });

        final currencyService = CurrencyService();
        final currency =
            currencyService.getCurrencyByCode(newCurrency) ??
                currencyService.getDefaultCurrency();
        await currencyService.setSelectedCurrency(currency);

        setState(() {
          selectedCurrency = newCurrency;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Currency updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating currency: $e')),
      );
    }
  }

  void _showCurrencyDialog() {
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
              final currency =
                  CurrencyService.supportedCurrencies.keys.elementAt(index);
              final currencyInfo =
                  CurrencyService.supportedCurrencies[currency];
              return ListTile(
                title: Text(currencyInfo ?? currency),
                trailing: currency == selectedCurrency
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

  void _setParticipants(List<String> friends) {
    final members = ['You', ...friends];
    setState(() {
      allParticipants = members;
      selectedParticipants = {for (var name in members) name: true};
      paidBy = 'You';
      
      // Initialize share controllers for all participants
      for (var participant in members) {
        if (!shareControllers.containsKey(participant)) {
          shareControllers[participant] = TextEditingController();
        }
      }
      
      // Reset custom shares
      customShares = {};
      for (var participant in members) {
        customShares[participant] = 0.0;
        if (shareControllers.containsKey(participant)) {
          shareControllers[participant]!.text = '';
        }
      }
    });
  }

  Future<void> _pickImage() async {
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    final imageBytes = await pickedFile.readAsBytes();
    setState(() {
      _receiptImage = File(pickedFile.path);
      _base64Image = base64Encode(imageBytes);
    });
  }
}


  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate() || selectedActivityId == null)
      return;

    // Validate split amounts match total for unequal and percentage splits
    if (splitMethod == 'unequally') {
      final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
      final totalShares = customShares.values.fold(0.0, (sum, amount) => sum + amount);
      
      if ((totalAmount - totalShares).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total shares ($totalShares) must equal the expense amount ($totalAmount)')),
        );
        return;
      }
    }

    final user = _auth.currentUser!;
    final selectedActivity = userActivities.firstWhere((a) => a['id'] == selectedActivityId);
    final ownerId = selectedActivity['ownerId'] ?? user.uid;
    final expense = {
      'title': _titleController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'currency': selectedCurrency,
      'date': DateFormat.yMMMd().format(selectedDate),
      'description': _descriptionController.text.trim(),
      // Store the actual user name/email, not "You"
      'paid_by': paidBy == 'You' ? (_auth.currentUser!.displayName ?? _auth.currentUser!.email) : paidBy,
      // Always store the user ID for the payer
      'paid_by_id': paidBy == 'You' ? _auth.currentUser!.uid : null,
      'split': splitMethod,
      'category': selectedCategory, // Add category to the expense
      'participants': selectedParticipants.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      if (_base64Image != null) 'receipt_image': _base64Image, 
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Handle different split methods
    if (splitMethod == 'unequally') {
      // Create shares map for unequal split
      final shares = <String, double>{};
      final participants = selectedParticipants.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      for (var participant in participants) {
        shares[participant] = customShares[participant] ?? 0.0;
      }
      
      expense['shares'] = shares;
    } else if (splitMethod == 'percentage') {
      // Create shares map for percentage split
      final shares = <String, double>{};
      final participants = selectedParticipants.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      for (var participant in participants) {
        shares[participant] = customShares[participant] ?? 0.0;
      }
      
      expense['shares'] = shares;
    }

    await _firestore
        .collection('users')
        .doc(ownerId)
        .collection('activities')
        .doc(selectedActivityId)
        .collection('transactions')
        .add(expense);

    // After submission, trigger balance recalculation
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added, recalculating balances...')),
      );
    }

    // Return true to indicate successful addition
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Select Activity",
                  prefixIcon: const Icon(Icons.event, color: Color(0xFFB19CD9)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                ),
                value: selectedActivityId,
                items: userActivities.map((activity) {
                  return DropdownMenuItem<String>(
                    value: activity['id'],
                    child: Text(activity['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  final selected = userActivities.firstWhere(
                    (act) => act['id'] == value,
                  );
                  setState(() {
                    selectedActivityId = value;
                    selectedActivityName = selected['name'];
                    _setParticipants(List<String>.from(selected['friends']!));
                  });
                },
              ),
              const SizedBox(height: 16),
              // Currency
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFB19CD9)),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                ),
                
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Currency: $selectedCurrency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB19CD9)),
                    ),
                    TextButton(
                      onPressed: _showCurrencyDialog,
                      child: const Text(
                        'Change',
                        style: TextStyle(color: Color(0xFFF5A9C1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  prefixIcon: const Icon(Icons.title, color: Color(0xFFB19CD9)),
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
                validator: (val) => val!.isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixIcon: const Icon(
                    Icons.attach_money,
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
                validator: (val) => val!.isEmpty ? "Enter an amount" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Date",
                  prefixIcon: const Icon(
                    Icons.date_range,
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
                controller: TextEditingController(
                  text: DateFormat.yMd().format(selectedDate),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Description (optional)",
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
              const SizedBox(height: 16),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Category",
                  prefixIcon: const Icon(Icons.category, color: Color(0xFFB19CD9)),
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
                value: selectedCategory,
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Color(0xFFB19CD9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Color(0xFFB19CD9),
                      ),
                      title: const Text("Tap to add a receipt image"),
                      subtitle: _receiptImage != null ? const Text("Image selected") : null,
                      onTap: _pickImage,
                    ),
                    if (_base64Image != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Image.memory(
                          base64Decode(_base64Image!),
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                "Paid By",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Column(
                children:
                    allParticipants
                        .map(
                          (name) => RadioListTile<String>(
                            title: Text(name),
                            value: name,
                            groupValue: paidBy,
                            activeColor: Color(0xFFB19CD9),
                            onChanged:
                                (value) => setState(() => paidBy = value),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                "Split",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Equally"),
                    selected: splitMethod == 'equally',
                    selectedColor: Color(0xFFF5A9C1),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          splitMethod == 'equally'
                              ? Colors.white
                              : Color(0xFFB19CD9),
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: Color(0xFFB19CD9)),
                    onSelected: (_) => setState(() => splitMethod = 'equally'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Unequally"),
                    selected: splitMethod == 'unequally',
                    selectedColor: Color(0xFFF5A9C1),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          splitMethod == 'unequally'
                              ? Colors.white
                              : Color(0xFFB19CD9),
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: Color(0xFFB19CD9)),
                    onSelected:
                        (_) => setState(() => splitMethod = 'unequally'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("By %"),
                    selected: splitMethod == 'percentage',
                    selectedColor: Color(0xFFF5A9C1),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          splitMethod == 'percentage'
                              ? Colors.white
                              : Color(0xFFB19CD9),
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: Color(0xFFB19CD9)),
                    onSelected:
                        (_) => setState(() => splitMethod = 'percentage'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Add the split method UI
              _buildSplitMethodUI(),
              const SizedBox(height: 24),
              const Text(
                "Participants",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...allParticipants.map(
                (name) => CheckboxListTile(
                  title: Text(name),
                  value: selectedParticipants[name] ?? false,
                  activeColor: Color(0xFFB19CD9),
                  onChanged:
                      (value) =>
                          setState(() => selectedParticipants[name] = value!),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
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
                  onPressed: _submitExpense,
                  child: const Text(
                    "ADD EXPENSE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitMethodUI() {
    final activeParticipants = selectedParticipants.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
        
    if (activeParticipants.isEmpty) {
      return const Text('Please select participants first');
    }
    
    if (splitMethod == 'equally') {
      // For equally split, just show the participants
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Each person pays:'),
          const SizedBox(height: 8),
          ...activeParticipants.map((name) {
            double amount = 0.0;
            try {
              amount = _amountController.text.isEmpty 
                  ? 0.0 
                  : (double.parse(_amountController.text) / activeParticipants.length);
            } catch (e) {
              // Handle parsing error
              print('Error parsing amount: $e');
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name),
                  Text('$selectedCurrency ${amount.toStringAsFixed(2)}'),
                ],
              ),
            );
          }).toList(),
        ],
      );
    } else if (splitMethod == 'unequally') {
      // For unequal split, show text fields for each participant
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Enter amount for each person:'),
          const SizedBox(height: 8),
          ...activeParticipants.map((name) {
            // Make sure controller exists
            if (!shareControllers.containsKey(name)) {
              shareControllers[name] = TextEditingController();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(name),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: shareControllers[name],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: '$selectedCurrency ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          customShares[name] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '$selectedCurrency ${customShares.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_amountController.text.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expense amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$selectedCurrency ${double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          if (_amountController.text.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Difference:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$selectedCurrency ${((double.tryParse(_amountController.text) ?? 0.0) - customShares.values.fold(0.0, (sum, amount) => sum + amount)).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ((double.tryParse(_amountController.text) ?? 0.0) - customShares.values.fold(0.0, (sum, amount) => sum + amount)).abs() < 0.01
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
        ],
      );
    } else if (splitMethod == 'percentage') {
      // For percentage split, show percentage fields for each participant
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Enter percentage for each person:'),
          const SizedBox(height: 8),
          ...activeParticipants.map((name) {
            // Make sure controller exists
            if (!shareControllers.containsKey(name)) {
              shareControllers[name] = TextEditingController();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(name),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: shareControllers[name],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          customShares[name] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total percentage:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${customShares.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (customShares.values.fold(0.0, (sum, amount) => sum + amount) - 100.0).abs() < 0.1
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
          if (_amountController.text.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('Amount breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...activeParticipants.map((name) {
                  final percentage = customShares[name] ?? 0.0;
                  double amount = 0.0;
                  try {
                    amount = _amountController.text.isEmpty
                        ? 0.0
                        : (double.parse(_amountController.text) * percentage / 100);
                  } catch (e) {
                    // Handle parsing error
                    print('Error parsing amount: $e');
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name),
                        Text('$selectedCurrency ${amount.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
        ],
      );
    }
    
    return const SizedBox();
  }
}
