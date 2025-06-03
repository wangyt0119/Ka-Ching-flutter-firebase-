import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import 'edit_expense_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final String? activityId;

  const TransactionDetailScreen({
    super.key, 
    required this.transactionId, 
    this.activityId,
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
        
        // If we have an activity ID, fetch from activity's transactions
        if (widget.activityId != null) {
          transactionDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .doc(widget.activityId)
              .collection('transactions')
              .doc(widget.transactionId)
              .get();
              
          // Also fetch activity details
          final activityDoc = await _firestore
              .collection('users')
              .doc(user.uid)
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
      final user = _auth.currentUser;
      if (user != null && _transaction != null) {
        if (widget.activityId != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .doc(widget.activityId)
              .collection('transactions')
              .doc(widget.transactionId)
              .delete();
        } else {
          await _firestore
              .collection('transactions')
              .doc(widget.transactionId)
              .delete();
        }
        
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting transaction: ${e.toString()}')),
      );
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

  // Add a confirmation dialog before deleting
  Future<void> _confirmDeleteTransaction() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          if (_transaction != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDeleteTransaction,
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
                                  Text(
                                    '${_transaction!['currency'] ?? '\$'}${(_transaction!['amount'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF5A9C1),
                                    ),
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
                      '${_transaction!['currency'] ?? '\$'}${(participant['share'] ?? 0.0).toStringAsFixed(2)}',
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
