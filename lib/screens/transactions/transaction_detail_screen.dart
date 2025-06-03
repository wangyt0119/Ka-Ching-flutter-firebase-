import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
            double? share;
            if (data['split'] == 'equally') {
              share = (data['amount'] ?? 0) / participantsList.length;
            } else if (data['split'] == 'percentage' && data['shares'] != null) {
              final percentage = data['shares'][participantId] ?? 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5A9C1),
        elevation: 0,
        title: const Text(
          'Transaction Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              _editTransaction();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Transaction'),
                  content: const Text('Are you sure you want to delete this transaction?'),
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
                                  Expanded(
                                    child: Text(
                                      _transaction!['title'] ?? 'Untitled',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${(_transaction!['amount'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_activity != null)
                                Chip(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  label: Text(
                                    _activity!['name'] ?? 'Unknown Activity',
                                    style: TextStyle(color: AppTheme.primaryColor),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _transaction!['date'] ?? 'Unknown date',
                                    style: const TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Paid by ${_transaction!['paid_by'] ?? 'Unknown'}',
                                    style: const TextStyle(color: AppTheme.textSecondary),
                                  ),
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
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Split ${_transaction!['split'] == 'equally' ? 'equally' : 'by percentage'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._participants.map((participant) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(participant['name']),
                                      Text(
                                        '\$${(participant['share'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      
                      // Receipt image if available
                      if (_transaction!['receipt_url'] != null)
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
                                padding: const EdgeInsets.all(8),
                                child: Image.network(
                                  _transaction!['receipt_url'],
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / 
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text('Failed to load receipt image'),
                                    );
                                  },
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
}




