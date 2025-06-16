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

  Map<String, double> customShares = {};
  Map<String, TextEditingController> shareControllers = {};

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
    
    // Set split method - ensure we have all three options
    splitMethod = widget.transaction['split'] ?? 'equally';
    
    // Set paid by
    paidBy = widget.transaction['paid_by'] ?? 'You';
    
    // Set participants
    if (widget.transaction['participants'] != null) {
      final participants = List<String>.from(widget.transaction['participants']);
      
      // Load activity members to get the full list of possible participants
      _loadActivityMembers().then((_) {
        setState(() {
          // Set selected participants based on transaction data
          selectedParticipants = {
            for (var name in allParticipants) 
              name: participants.contains(name)
          };
        });
      });
    } else {
      _loadActivityMembers();
      selectedParticipants = {'You': true};
    }
    
    // Load custom shares if available
    if (widget.transaction['shares'] != null) {
      final shares = Map<String, dynamic>.from(widget.transaction['shares']);
      
      // Convert to double values
      customShares = shares.map((key, value) => 
        MapEntry(key, value is num ? value.toDouble() : 0.0));
    }
    
    // Initialize receipt image if available
    if (widget.transaction['receipt_image'] != null) {
      _base64Image = widget.transaction['receipt_image'];
    }
    
    // Initialize share controllers
    _initializeShareControllers();
  }

  void _initializeShareControllers() {
    // Clear existing controllers
    shareControllers.clear();
    
    // Create controllers for each participant
    for (var participant in allParticipants) {
      // For the current user (You), check if there's an existing share under their actual name
      String shareKey = participant;
      if (participant == 'You' && widget.transaction['shares'] != null) {
        // Try to find the current user's share in the transaction data
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          final shares = Map<String, dynamic>.from(widget.transaction['shares']);
          
          // Check if there's a share for "You" or for the user's display name
          if (shares.containsKey('You')) {
            shareKey = 'You';
          } else if (currentUser.displayName != null && shares.containsKey(currentUser.displayName)) {
            shareKey = currentUser.displayName!;
          }
        }
      }
      
      // Initialize with existing share value if available
      String initialValue = '';
      if (widget.transaction['shares'] != null) {
        final shares = Map<String, dynamic>.from(widget.transaction['shares']);
        if (shares.containsKey(shareKey)) {
          final shareValue = shares[shareKey];
          initialValue = shareValue.toString();
        }
      }
      
      shareControllers[participant] = TextEditingController(text: initialValue);
      
      // Add listener to update customShares when text changes
      shareControllers[participant]!.addListener(() {
        final value = double.tryParse(shareControllers[participant]!.text) ?? 0.0;
        setState(() {
          customShares[participant] = value;
        });
      });
      
      // Initialize customShares with the initial value
      if (initialValue.isNotEmpty) {
        customShares[participant] = double.tryParse(initialValue) ?? 0.0;
      }
    }
  }

  Future<void> _loadActivityMembers() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // First get the current user's display name or email
        String currentUserName = 'You';
        
        // Get user document to check if this is the current user's profile
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data();
        final currentUserEmail = userData?['email'] ?? currentUser.email ?? '';
        final currentUserDisplayName = userData?['displayName'] ?? currentUser.displayName ?? '';
        
        // Get activity members
        final activityDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('activities')
            .doc(selectedActivityId)
            .get();
        
        if (activityDoc.exists) {
          final activityData = activityDoc.data();
          if (activityData != null && activityData['members'] != null) {
            final members = List<Map<String, dynamic>>.from(activityData['members']);
            
            // Extract member names, ensuring current user is represented as "You"
            final List<String> memberNames = [];
            
            // Add current user as "You"
            memberNames.add('You');
            
            // Add other members, excluding the current user
            for (var member in members) {
              final name = member['name'] as String;
              final email = member['email'] as String? ?? '';
              
              // Skip if this is the current user (already added as "You")
              if ((name == currentUserDisplayName || email == currentUserEmail) && 
                  name != 'You') {
                continue;
              }
              
              // Add other members
              if (name != 'You') {
                memberNames.add(name);
              }
            }
            
            setState(() {
              allParticipants = memberNames;
              
              // Update selected participants
              if (widget.transaction['participants'] != null) {
                final participants = List<String>.from(widget.transaction['participants']);
                
                // Map old participant names to new ones if needed
                selectedParticipants = {};
                for (var name in allParticipants) {
                  if (name == 'You') {
                    // Check if current user was in participants
                    selectedParticipants[name] = participants.contains(currentUserDisplayName) || 
                                                participants.contains('You');
                  } else {
                    selectedParticipants[name] = participants.contains(name);
                  }
                }
              }
              
              // Update paidBy if needed
              if (paidBy == currentUserDisplayName) {
                paidBy = 'You';
              }
              
              // Re-initialize share controllers
              _initializeShareControllers();
            });
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activity members: $error')),
        );
      }
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
                  Navigator.pop(context,true);
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get active participants
      final activeParticipants = selectedParticipants.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
          
      if (activeParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one participant')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Validate split amounts match total for unequal and percentage splits
      if (splitMethod == 'unequally') {
        final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
        final totalShares = activeParticipants.fold(
          0.0, 
          (sum, name) => sum + (customShares[name] ?? 0.0)
        );
        
        if ((totalAmount - totalShares).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Total shares ($totalShares) must equal the expense amount ($totalAmount)')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else if (splitMethod == 'percentage') {
        final totalPercentage = activeParticipants.fold(
          0.0, 
          (sum, name) => sum + (customShares[name] ?? 0.0)
        );
        
        if ((totalPercentage - 100.0).abs() > 0.1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Total percentage must equal 100% (currently $totalPercentage%)')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final user = _auth.currentUser!;
      final expense = {
        'title': _titleController.text.trim(),
        'amount': double.tryParse(_amountController.text.trim()) ?? 0,
        'currency': selectedCurrency,
        'date': DateFormat.yMMMd().format(selectedDate),
        'description': _descriptionController.text.trim(),
        'paid_by': paidBy,
        'split': splitMethod,
        'participants': activeParticipants,
        if (_base64Image != null) 'receipt_image': _base64Image,
      };

      // Handle different split methods
      if (splitMethod == 'unequally' || splitMethod == 'percentage') {
        // Create shares map for unequal or percentage split
        final shares = <String, double>{};
        
        for (var participant in activeParticipants) {
          shares[participant] = customShares[participant] ?? 0.0;
        }
        
        expense['shares'] = shares;
      }

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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating transaction: $error')),
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
                    
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        prefixIcon: const Icon(Icons.title, color: Color(0xFFB19CD9)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Amount and currency
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixIcon: const Icon(Icons.attach_money, color: Color(0xFFB19CD9)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: _showCurrencyDialog,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Currency',
                                border: OutlineInputBorder(
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
                    
                    // Date picker
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFFB19CD9)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat.yMMMd().format(selectedDate)),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: const Icon(Icons.description, color: Color(0xFFB19CD9)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                                      const BorderSide(color: Color(0xFFB19CD9)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Receipt image
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
                    if (_base64Image != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_base64Image!),
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    
                    // Paid by section
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
                    
                    // Split method section
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
                            color: splitMethod == 'equally' ? Colors.white : Color(0xFFB19CD9),
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
                            color: splitMethod == 'unequally' ? Colors.white : Color(0xFFB19CD9),
                            fontWeight: FontWeight.bold,
                          ),
                          side: const BorderSide(color: Color(0xFFB19CD9)),
                          onSelected: (_) => setState(() => splitMethod = 'unequally'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("By %"),
                          selected: splitMethod == 'percentage',
                          selectedColor: Color(0xFFF5A9C1),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: splitMethod == 'percentage' ? Colors.white : Color(0xFFB19CD9),
                            fontWeight: FontWeight.bold,
                          ),
                          side: const BorderSide(color: Color(0xFFB19CD9)),
                          onSelected: (_) => setState(() => splitMethod = 'percentage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Split method UI
                    _buildSplitMethodUI(),
                    const SizedBox(height: 24),
                    
                    // Participants section
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
                    
                    // Update button
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

  // Split method UI builder
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
            final amount = _amountController.text.isEmpty 
                ? 0.0 
                : (double.parse(_amountController.text) / activeParticipants.length);
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
                        prefixText: selectedCurrency + ' ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        final amount = double.tryParse(value) ?? 0.0;
                        setState(() {
                          customShares[name] = amount;
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
              const Text('Total amount:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '$selectedCurrency ${customShares.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (_amountController.text.isEmpty ? 0.0 : double.parse(_amountController.text) - customShares.values.fold(0.0, (sum, amount) => sum + amount)).abs() < 0.01
                      ? Colors.green
                      : Colors.red,
                ),
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
                      ),
                      onChanged: (value) {
                        final percentage = double.tryParse(value) ?? 0.0;
                        setState(() {
                          customShares[name] = percentage;
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
                '${customShares.entries.where((e) => activeParticipants.contains(e.key)).fold(0.0, (sum, e) => sum + e.value).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (customShares.entries.where((e) => activeParticipants.contains(e.key)).fold(0.0, (sum, e) => sum + e.value) - 100.0).abs() < 0.1
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
                  final amount = _amountController.text.isEmpty
                      ? 0.0
                      : (double.parse(_amountController.text) * percentage / 100);
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
