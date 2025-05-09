import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

  String? selectedActivityId;
  String? selectedActivityName;
  List<Map<String, dynamic>> userActivities = [];

  DateTime selectedDate = DateTime.now();
  File? receiptImage;
  String splitMethod = 'equally';
  String? paidBy = 'You';

  List<String> allParticipants = [];
  Map<String, bool> selectedParticipants = {};

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    final user = FirebaseAuth.instance.currentUser!;
    final snapshot = await FirebaseFirestore.instance
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

  void _setParticipants(List<String> friends) {
    final members = ['You', ...friends];
    setState(() {
      allParticipants = members;
      selectedParticipants = {
        for (var name in members) name: name == 'You',
      };
      paidBy = 'You';
    });
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => receiptImage = File(pickedFile.path));
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate() || selectedActivityId == null) return;

    final user = FirebaseAuth.instance.currentUser!;
    final expense = {
      'title': _titleController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'date': DateFormat.yMMMd().format(selectedDate),
      'description': _descriptionController.text.trim(),
      'paid_by': paidBy,
      'split': splitMethod,
      'participants': selectedParticipants.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
    };

    await FirebaseFirestore.instance
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
      backgroundColor: const Color(0xFFF6F0FA),
      appBar: AppBar(
        backgroundColor: Colors.pink.shade100,
        title: const Text('Add Expense', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Select Activity",
                  prefixIcon: Icon(Icons.event),
                ),
                value: selectedActivityId,
                items: userActivities.map((activity) {
                  return DropdownMenuItem<String>(
                    value: activity['id'],
                    child: Text(activity['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  final selected = userActivities
                      .firstWhere((act) => act['id'] == value);
                  setState(() {
                    selectedActivityId = value;
                    selectedActivityName = selected['name'];
                    _setParticipants(List<String>.from(selected['friends']!));
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: "Title", prefixIcon: Icon(Icons.title)),
                validator: (val) => val!.isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Amount", prefixIcon: Icon(Icons.attach_money)),
                validator: (val) => val!.isEmpty ? "Enter an amount" : null,
              ),
              const SizedBox(height: 10),
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
                  prefixIcon: const Icon(Icons.date_range),
                  hintText: DateFormat.yMd().format(selectedDate),
                ),
                controller: TextEditingController(
                    text: DateFormat.yMd().format(selectedDate)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description (optional)",
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text("Tap to add a receipt image"),
                subtitle:
                    receiptImage != null ? const Text("Image selected") : null,
                onTap: _pickImage,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Paid By", style: Theme.of(context).textTheme.titleSmall),
              ),
              Column(
                children: allParticipants
                    .map((name) => RadioListTile<String>(
                          title: Text(name),
                          value: name,
                          groupValue: paidBy,
                          onChanged: (value) => setState(() => paidBy = value),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Split", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("Equally"),
                        selected: splitMethod == 'equally',
                        onSelected: (_) => setState(() => splitMethod = 'equally'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Unequally"),
                        selected: splitMethod == 'unequally',
                        onSelected: (_) => setState(() => splitMethod = 'unequally'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("By %"),
                        selected: splitMethod == 'percentage',
                        onSelected: (_) => setState(() => splitMethod = 'percentage'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Participants", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...allParticipants.map((name) => CheckboxListTile(
                    title: Text(name),
                    value: selectedParticipants[name] ?? false,
                    onChanged: (value) =>
                        setState(() => selectedParticipants[name] = value!),
                  )),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade100,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _submitExpense,
                child: const Text("ADD EXPENSE"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
