import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import 'edit_expense_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final String? activityId;
  final String? ownerId;

  const TransactionDetailScreen({
    super.key, 
    required this.transactionId, 
    this.activityId,
    this.ownerId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  Map<String, dynamic>? _transaction;
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
  }

  Future<void> _loadTransactionData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot? transactionDoc;
        String ownerId = widget.ownerId ?? user.uid;
        // If we have an activity ID, fetch from activity's transactions
        if (widget.activityId != null) {
          transactionDoc = await _firestore
              .collection('users')
              .doc(ownerId)
              .collection('activities')
              .doc(widget.activityId)
              .collection('transactions')
              .doc(widget.transactionId)
              .get();
              
          // Also fetch activity details
          final activityDoc = await _firestore
              .collection('users')
              .doc(ownerId)
              .collection('activities')
              .doc(widget.activityId)
              .get();
              
          if (activityDoc.exists) {
            setState(() {
              _activity = activityDoc.data();
              _activity!['id'] = activityDoc.id;
            });
          }
        } else {
          // Otherwise try to fetch from general transactions
          transactionDoc = await _firestore
              .collection('transactions')
              .doc(widget.transactionId)
              .get();
        }

        if (transactionDoc != null && transactionDoc.exists) {
          final data = transactionDoc.data() as Map<String, dynamic>;
          data['id'] = transactionDoc.id;
          
          // Process participants data
          List<dynamic> participantsList = data['participants'] ?? [];
          List<Map<String, dynamic>> processedParticipants = [];
          
          for (String participantId in participantsList) {
            double share = 0.0;
            
            if (data['split'] == 'equally') {
              // For equal split
              share = (data['amount'] ?? 0) / participantsList.length;
            } else if (data['split'] == 'unequally' && data['shares'] != null) {
              // For unequal split
              final shares = Map<String, dynamic>.from(data['shares']);
              share = shares[participantId]?.toDouble() ?? 0.0;
            } else if (data['split'] == 'percentage' && data['shares'] != null) {
              // For percentage split
              final shares = Map<String, dynamic>.from(data['shares']);
              final percentage = shares[participantId]?.toDouble() ?? 0.0;
              share = (data['amount'] ?? 0) * percentage / 100;
            }
            
            processedParticipants.add({
              'name': participantId,
              'share': share,
            });
          }

          setState(() {
            _transaction = data;
            _participants = processedParticipants;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction not found')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading transaction: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteTransaction() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ownerId = widget.ownerId ?? user.uid;
      final activityId = widget.activityId;
      final transactionId = widget.transactionId;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .collection('activities')
          .doc(activityId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully')),
        );
        Navigator.pop(context, true); // Pop and signal deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting transaction: $e')),
        );
      }
    }
  }

  Future<void> _editTransaction() async {
    if (_transaction == null || widget.activityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit this transaction')),
      );
      return;
    }
    
    // Navigate to edit transaction screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditExpenseScreen(
          activityId: widget.activityId!,
          activityName: _activity?['name'] ?? 'Activity',
          transaction: _transaction!,
        ),
      ),
    );
    
    // Reload transaction data if edited successfully
    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      await _loadTransactionData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB19CD9),
        foregroundColor: Colors.white,
        title: const Text('Transaction Details'),
        actions: [
          if (_transaction != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editTransaction,
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Transaction'),
                  content: const Text('Are you sure you want to delete this transaction?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteTransaction();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? const Center(child: Text('Transaction not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transaction Card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _transaction!['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Original value
                                      Text(
                                        () {
                                          final originalAmount = _transaction!['amount'] ?? 0.0;
                                          final originalCurrency = _transaction!['currency'] ?? 'USD';
                                          return '$originalCurrency ${originalAmount.toStringAsFixed(2)}';
                                        }(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      // Converted value
                                      Text(
                                        () {
                                          final currencyProvider = Provider.of<CurrencyProvider>(context);
                                          final originalAmount = _transaction!['amount'] ?? 0.0;
                                          final originalCurrency = _transaction!['currency'] ?? 'USD';
                                          final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
                                            (c) => c.code == originalCurrency,
                                            orElse: () => currencyProvider.selectedCurrency,
                                          );
                                          final converted = currencyProvider.convertToSelectedCurrency(originalAmount.toDouble(), fromCurrency);
                                          return currencyProvider.formatAmount(converted);
                                        }(),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF5A9C1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(_transaction!['date'] ?? 'Unknown date'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Paid by ${_transaction!['paid_by'] ?? 'Unknown'}'),
                                ],
                              ),
                              if (_transaction!['description'] != null && _transaction!['description'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Description',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_transaction!['description']),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Show user's share
                              Builder(
                                builder: (context) {
                                  final participants = List<String>.from(_transaction!['participants'] ?? []);
                                  String userKey = '';
                                  if (participants.contains(userId)) {
                                    userKey = userId!;
                                  } else if (participants.contains(userEmail)) {
                                    userKey = userEmail!;
                                  }
                                  double userShare = 0.0;
                                  if (userKey.isNotEmpty) {
                                    if (_transaction!['split'] == 'equally') {
                                      userShare = (_transaction!['amount'] ?? 0.0) / participants.length;
                                    } else if (_transaction!['split'] == 'unequally' && _transaction!['shares'] != null) {
                                      final shares = Map<String, dynamic>.from(_transaction!['shares']);
                                      userShare = shares[userKey]?.toDouble() ?? 0.0;
                                    } else if (_transaction!['split'] == 'percentage' && _transaction!['shares'] != null) {
                                      final shares = Map<String, dynamic>.from(_transaction!['shares']);
                                      final percentage = shares[userKey]?.toDouble() ?? 0.0;
                                      userShare = (_transaction!['amount'] ?? 0.0) * percentage / 100;
                                    }
                                  }
                                  final paidBy = _transaction!['paid_by'];
                                  final isPayer = paidBy == userKey;
                                  final currencyProvider = Provider.of<CurrencyProvider>(context);
                                  final originalCurrency = _transaction!['currency'] ?? 'USD';
                                  final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
                                    (c) => c.code == originalCurrency,
                                    orElse: () => currencyProvider.selectedCurrency,
                                  );
                                  final convertedShare = currencyProvider.convertToSelectedCurrency(userShare, fromCurrency);
                                  if (userKey.isEmpty) return const SizedBox();
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isPayer ? 'You paid' : (userShare > 0 ? 'You get back' : 'You owe'),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        currencyProvider.formatAmount(convertedShare.abs()),
                                        style: TextStyle(
                                          color: userShare >= 0 ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Split details
                      const Text(
                        'Split Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSplitDetailsCard(),
                      
                      // Receipt image if available
                      if (_transaction!['receipt_image'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            const Text(
                              'Receipt',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Image.memory(
                                  base64Decode(_transaction!['receipt_image']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }

  // Helper method to get the split method text
  String _getSplitMethodText() {
    final splitMethod = _transaction?['split'] ?? 'equally';
    
    switch (splitMethod) {
      case 'equally':
        return 'Split equally';
      case 'unequally':
        return 'Split unequally';
      case 'percentage':
        return 'Split by percentage';
      default:
        return 'Split equally';
    }
  }

  // Fix the transaction detail screen to properly display split information
  Widget _buildSplitDetailsCard() {
    if (_transaction == null || _participants.isEmpty) {
      return const SizedBox();
    }
    
    final splitMethod = _transaction!['split'] ?? 'equally';
    String splitMethodText;
    
    switch (splitMethod) {
      case 'equally':
        splitMethodText = 'Split equally';
        break;
      case 'unequally':
        splitMethodText = 'Split unequally';
        break;
      case 'percentage':
        splitMethodText = 'Split by percentage';
        break;
      default:
        splitMethodText = 'Split equally';
    }
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              splitMethodText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            // Show participant shares
            ..._participants.map((participant) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(participant['name']),
                    Text(
                      () {
                        final currencyProvider = Provider.of<CurrencyProvider>(context);
                        final originalAmount = participant['share'] ?? 0.0;
                        final originalCurrency = _transaction!['currency'] ?? 'USD';
                        final fromCurrency = currencyProvider.availableCurrencies.firstWhere(
                          (c) => c.code == originalCurrency,
                          orElse: () => currencyProvider.selectedCurrency,
                        );
                        final converted = currencyProvider.convertToSelectedCurrency(originalAmount.toDouble(), fromCurrency);
                        return currencyProvider.formatAmount(converted);
                      }(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            // Show percentages if split by percentage
            if (splitMethod == 'percentage' && _transaction!['shares'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Percentage Breakdown:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._participants.map((participant) {
                    final shares = Map<String, dynamic>.from(_transaction!['shares']);
                    final percentage = shares[participant['name']]?.toDouble() ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(participant['name']),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
