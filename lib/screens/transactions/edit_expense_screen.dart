import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/currency_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final String activityId;
  final String activityName;
  final Map<String, dynamic> transaction;

  const EditExpenseScreen({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.transaction,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedActivityId;
  String? selectedActivityName;

  late String selectedCurrency;
  late DateTime selectedDate;
  File? _receiptImage;
  String? _base64Image;

  late String splitMethod;
  late String? paidBy;
  Map<String, bool> selectedParticipants = {};
  List<String> allParticipants = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing transaction data
    _titleController = TextEditingController(text: widget.transaction['title'] ?? '');
    _amountController = TextEditingController(
      text: (widget.transaction['amount'] ?? 0.0).toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction['description'] ?? '',
    );
    
    // Set other fields from transaction data
    selectedActivityId = widget.activityId;
    selectedActivityName = widget.activityName;
    selectedCurrency = widget.transaction['currency'] ?? 'USD';
    
    // Parse date
    if (widget.transaction['date'] is Timestamp) {
      selectedDate = (widget.transaction['date'] as Timestamp).toDate();
    } else if (widget.transaction['date'] is String) {
      try {
        selectedDate = DateFormat.yMMMd().parse(widget.transaction['date']);
      } catch (e) {
        selectedDate = DateTime.now();
      }
    } else {
      selectedDate = DateTime.now();
    }
    
    // Set split method
    splitMethod = widget.transaction['split'] ?? 'equally';
    
    // Set paid by
    paidBy = widget.transaction['paid_by'] ?? 'You';
    
    // Set participants
    if (widget.transaction['participants'] != null) {
      final participants = List<String>.from(widget.transaction['participants']);
      allParticipants = ['You', ...participants.where((p) => p != 'You')];
      selectedParticipants = {
        for (var name in allParticipants) 
          name: participants.contains(name)
      };
    } else {
      allParticipants = ['You'];
      selectedParticipants = {'You': true};
    }
    
    // Set receipt image if available
    _base64Image = widget.transaction['receipt_image'];
    
    // Load activity members
    _loadActivityMembers();
  }

  Future<void> _loadActivityMembers() async {
    try {
      final activityDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .collection('activities')
          .doc(widget.activityId)
          .get();
      
      if (activityDoc.exists) {
        final activityData = activityDoc.data();
        if (activityData != null && activityData['members'] != null) {
          final members = List<Map<String, dynamic>>.from(activityData['members']);
          final memberNames = members.map((m) => m['name'] as String).toList();
          
          setState(() {
            allParticipants = ['You', ...memberNames.where((name) => name != 'You')];
            
            // Preserve selected participants
            final selectedNames = selectedParticipants.keys.toList();
            selectedParticipants = {
              for (var name in allParticipants) 
                name: selectedNames.contains(name) ? selectedParticipants[name]! : false
            };
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity members: $e')),
      );
    }
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

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate() || selectedActivityId == null)
      return;

    setState(() {
      _isLoading = true;
    });

    try {
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
          .doc(widget.transaction['id'])
          .update(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5A9C1),
        title: const Text(
          'Edit Expense',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity Info (non-editable)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: Color(0xFFB19CD9)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Activity: $selectedActivityName',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                          Icons.calendar_today,
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
                        text: DateFormat.yMMMd().format(selectedDate),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Description (Optional)",
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
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _showCurrencyDialog,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Currency",
                                prefixIcon: const Icon(
                                  Icons.currency_exchange,
                                  color: Color(0xFFB19CD9),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(selectedCurrency),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickImage,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Receipt Image",
                                prefixIcon: const Icon(
                                  Icons.receipt_long,
                                  color: Color(0xFFB19CD9),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_receiptImage != null || _base64Image != null
                                      ? 'Receipt image selected'
                                      : 'No image selected'),
                                  const Icon(Icons.add_a_photo),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                        onPressed: _isLoading ? null : _updateExpense,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "UPDATE EXPENSE",
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