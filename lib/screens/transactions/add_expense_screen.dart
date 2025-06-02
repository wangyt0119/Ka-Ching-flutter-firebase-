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
  final String activityName;

  const AddExpenseScreen({
    super.key,
    required this.activityId,
    required this.activityName,
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

  String selectedCurrency = 'USD'; // default
  DateTime selectedDate = DateTime.now();
  File? _receiptImage;
  String? _base64Image;

  String splitMethod = 'equally';
  String? paidBy = 'You';

  List<String> allParticipants = [];
  Map<String, bool> selectedParticipants = {};

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _loadUserCurrency();
  }

  Future<void> _fetchActivities() async {
    final user = _auth.currentUser!;
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .get();

    final activities = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc.data()['name'] ?? 'Unnamed Activity',
        'friends': List<String>.from(doc.data()['friends'] ?? []),
      };
    }).toList();

    setState(() {
      userActivities = activities;
      if (activities.isNotEmpty) {
        selectedActivityId = activities[0]['id'];
        selectedActivityName = activities[0]['name'];
        _setParticipants(activities[0]['friends']);
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
      selectedParticipants = {for (var name in members) name: name == 'You'};
      paidBy = 'You';
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

    final user = _auth.currentUser!;
    final expense = {
      'title': _titleController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'currency': selectedCurrency,
      'date': DateFormat.yMMMd().format(selectedDate),
      'description': _descriptionController.text.trim(),
      'paid_by': paidBy,
      'split': splitMethod,
      'participants': selectedParticipants.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      if (_base64Image != null) 'receipt_image': _base64Image, 

    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .doc(selectedActivityId)
        .collection('transactions')
        .add(expense);

    Navigator.pop(context);
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
}
