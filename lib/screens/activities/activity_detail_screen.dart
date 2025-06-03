import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../transactions/add_expense_screen.dart';
import 'edit_activity_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

// Helper class for settlement options
class SettlementOption {
  final String name;
  final double balance;
  final String displayText;
  
  SettlementOption({
    required this.name,
    required this.balance,
    required this.displayText,
  });
}

class ActivityDetailsScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailsScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Load activity details
        final activityDoc =
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('activities')
                .doc(widget.activityId)
                .get();

        if (activityDoc.exists) {
          final activityData = activityDoc.data()!;
          activityData['id'] = activityDoc.id;

          // Load transactions for this activity
          final transactionsSnapshot =
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('activities')
                  .doc(widget.activityId)
                  .collection('transactions')
                  .orderBy('date', descending: true)
                  .get();

          final transactions =
              transactionsSnapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList();

          // Calculate total amount and balances
          double totalAmount = 0;
          Map<String, double> balances = {};

          for (var transaction in transactions) {
            final amount = transaction['amount']?.toDouble() ?? 0.0;
            final paidBy = transaction['paid_by'] ?? 'Unknown';
            final participants = List<String>.from(transaction['participants'] ?? []);
            
            print('Processing transaction: ${transaction['title']} with amount: $amount');
            print('Paid by: $paidBy, Participants: $participants');
            
            totalAmount += amount;

            // Add to payer's balance (they paid)
            balances[paidBy] = (balances[paidBy] ?? 0) + amount;

            // Subtract from participants' balances (they owe)
            final splitMethod = transaction['split'] ?? 'equally';
            
            if (splitMethod == 'equally' && participants.isNotEmpty) {
              final shareAmount = amount / participants.length;
              
              for (var participant in participants) {
                if (participant != paidBy) {
                  balances[participant] = (balances[participant] ?? 0) - shareAmount;
                }
              }
            } else if (splitMethod == 'percentage' && transaction['shares'] != null) {
              final shares = Map<String, dynamic>.from(transaction['shares']);
              
              for (var entry in shares.entries) {
                final participant = entry.key;
                final percentage = entry.value;
                
                if (participant != paidBy) {
                  final shareAmount = amount * percentage / 100;
                  balances[participant] = (balances[participant] ?? 0) - shareAmount;
                }
              }
            }
          }

          // After updating balances, log them
          print('Updated balances: $balances');

          // Update activity with total amount
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('activities')
              .doc(widget.activityId)
              .update({
            'totalAmount': totalAmount,
            'balances': balances,
          });

          activityData['totalAmount'] = totalAmount;
          activityData['balances'] = balances;

          setState(() {
            _activity = activityData;
            _transactions = transactions;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity: ${e.toString()}')),
      );
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCurrentUserPayer = transaction['paid_by'] == 'You';
    final amount = transaction['amount']?.toDouble() ?? 0.0;
    final date = transaction['date'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                transactionId: transaction['id'],
                activityId: widget.activityId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction['title'] ?? 'Untitled',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Paid by ${isCurrentUserPayer ? 'you' : transaction['paid_by']}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add a method to show who owes you money
  Widget _buildBalancesCard() {
    if (_activity == null || _activity!['balances'] == null) {
      return const SizedBox();
    }

    final balances = Map<String, double>.from(_activity!['balances']);
    final currentUserBalance = balances['You'] ?? 0.0;
    
    // Filter to show only people who owe you money (negative balances for others)
    final peopleWhoOweYou = balances.entries
        .where((entry) => entry.key != 'You' && entry.value < 0)
        .toList();
    
    // Filter to show people you owe money to (positive balances for others)
    final peopleYouOwe = balances.entries
        .where((entry) => entry.key != 'You' && entry.value > 0)
        .toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Balances',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            
            // Your overall balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your balance:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currentUserBalance >= 0 ? '+' : ''}${currentUserBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentUserBalance >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // People who owe you money
            if (peopleWhoOweYou.isNotEmpty) ...[
              const Text(
                'People who owe you:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...peopleWhoOweYou.map((entry) {
                final name = entry.key;
                final amount = entry.value.abs(); // Make positive for display
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name),
                      Text(
                        '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(height: 16),
            ],
            
            // People you owe money to
            if (peopleYouOwe.isNotEmpty) ...[
              const Text(
                'You owe:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...peopleYouOwe.map((entry) {
                final name = entry.key;
                final amount = entry.value; // Already positive
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name),
                      Text(
                        '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Add settle up button
            if (peopleWhoOweYou.isNotEmpty || peopleYouOwe.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A9C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showSettleUpDialog,
                  child: const Text('Settle Up'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add a method to show the settle up dialog
  void _showSettleUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Up'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select who you want to settle up with:'),
              const SizedBox(height: 16),
              ..._getSettlementOptions().map((option) {
                return ListTile(
                  title: Text(option.name),
                  subtitle: Text(option.displayText),
                  onTap: () {
                    Navigator.pop(context);
                    _showSettlementAmountDialog(option);
                  },
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Get settlement options
  List<SettlementOption> _getSettlementOptions() {
    if (_activity == null || _activity!['balances'] == null) {
      return [];
    }
    
    final balances = Map<String, double>.from(_activity!['balances']);
    final options = <SettlementOption>[];
    
    // Add people who owe you money
    for (var entry in balances.entries) {
      if (entry.key != 'You' && entry.value < 0) {
        options.add(SettlementOption(
          name: entry.key,
          balance: entry.value,
          displayText: '${entry.key} owes you ${_activity!['currency'] ?? '\$'}${entry.value.abs().toStringAsFixed(2)}',
        ));
      }
    }
    
    // Add people you owe money to
    for (var entry in balances.entries) {
      if (entry.key != 'You' && entry.value > 0) {
        options.add(SettlementOption(
          name: entry.key,
          balance: entry.value,
          displayText: 'You owe ${entry.key} ${_activity!['currency'] ?? '\$'}${entry.value.toStringAsFixed(2)}',
        ));
      }
    }
    
    return options;
  }

  // Add method to create settlement transaction
  Future<void> _createSettlementTransaction(String person, double balance) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Determine who is paying whom
        final isPositive = balance >= 0;
        final settlementTitle = isPositive 
            ? 'You settled debt with $person' 
            : '$person settled debt with you';
        
        // Create a settlement transaction
        final settlement = {
          'title': settlementTitle,
          'amount': balance.abs(),
          'currency': _activity!['currency'] ?? '\$',
          'date': DateFormat.yMMMd().format(DateTime.now()),
          'description': 'Settlement transaction',
          'paid_by': isPositive ? 'You' : person,
          'split': 'equally',
          'participants': [isPositive ? person : 'You'],
          'is_settlement': true,
          'timestamp': FieldValue.serverTimestamp(),
        };
        
        // Add the settlement transaction to the activity
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('activities')
            .doc(widget.activityId)
            .collection('transactions')
            .add(settlement);
        
        // Reload activity data to update balances
        await _loadActivityData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording settlement: $e')),
      );
    }
  }

  // Add this method to generate and export a PDF report
  Future<void> _generateActivityReport() async {
    try {
      if (_activity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No activity data to export')),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );

      // Create a PDF document
      final pdf = pw.Document();
      
      // Add activity info page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    'Activity Report',
                    style: pw.TextStyle(
                      fontSize: 24, 
                      fontWeight: pw.FontWeight.bold
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Activity details
                pw.Text(
                  'Activity: ${_activity!['name']}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Date: ${DateFormat('MMMM d, yyyy').format((_activity!['createdAt'] as Timestamp).toDate())}',
                ),
                if (_activity!['description'] != null && _activity!['description'] != '') ...[
                  pw.SizedBox(height: 5),
                  pw.Text('Description: ${_activity!['description']}'),
                ],
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total Amount: ${_activity!['currency'] ?? '\$'}${(_activity!['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                
                // Balances section
                pw.Text(
                  'Balances',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
        ),
      );
      
      // Add balances page
      if (_activity!['balances'] != null) {
        final balances = Map<String, double>.from(_activity!['balances']);
        final currentUserBalance = balances['You'] ?? 0.0;
        
        // People who owe you
        final peopleWhoOweYou = balances.entries
            .where((entry) => entry.key != 'You' && entry.value < 0)
            .toList();
        
        // People you owe
        final peopleYouOwe = balances.entries
            .where((entry) => entry.key != 'You' && entry.value > 0)
            .toList();
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Balances',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Your balance
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Your balance:'),
                      pw.Text(
                        '${currentUserBalance >= 0 ? '+' : ''}${currentUserBalance.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // People who owe you
                  if (peopleWhoOweYou.isNotEmpty) ...[
                    pw.Text('People who owe you:'),
                    pw.SizedBox(height: 10),
                    ...peopleWhoOweYou.map((entry) {
                      final name = entry.key;
                      final amount = entry.value.abs();
                      
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(name),
                            pw.Text(
                              '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    pw.SizedBox(height: 20),
                  ],
                  
                  // People you owe
                  if (peopleYouOwe.isNotEmpty) ...[
                    pw.Text('You owe:'),
                    pw.SizedBox(height: 10),
                    ...peopleYouOwe.map((entry) {
                      final name = entry.key;
                      final amount = entry.value;
                      
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(name),
                            pw.Text(
                              '${_activity!['currency'] ?? '\$'}${amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              );
            },
          ),
        );
      }
      
      // Add transactions page
      if (_transactions.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Transactions',
                      style: pw.TextStyle(
                        fontSize: 20, 
                        fontWeight: pw.FontWeight.bold
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Transactions table
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3), // Title
                      1: const pw.FlexColumnWidth(2), // Paid by
                      2: const pw.FlexColumnWidth(2), // Amount
                      3: const pw.FlexColumnWidth(2), // Date
                    },
                    children: [
                      // Table header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Title',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Paid by',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Amount',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'Date',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      
                      // Transaction rows (limit to first 20 to avoid overflow)
                      ...(_transactions.length > 20 ? _transactions.sublist(0, 20) : _transactions).map((transaction) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(transaction['title'] ?? 'Untitled'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(transaction['paid_by'] ?? ''),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                '${_activity!['currency'] ?? '\$'}${(transaction['amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(transaction['date'] ?? ''),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }
      
      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      
      // Share the PDF directly without saving to a file
      await Share.shareXFiles(
        [
          XFile.fromData(
            pdfBytes,
            name: '${_activity!['name'].toString().replaceAll(' ', '_')}_report.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        text: 'Activity Report',
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated and ready to share')),
      );
      
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  // Show dialog with export options
  void _showExportOptionsDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Generated'),
        content: const Text('Your activity report has been generated. What would you like to do with it?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('View'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareFiles([file.path], text: 'Activity Report');
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Show dialog to enter settlement amount
  void _showSettlementAmountDialog(SettlementOption option) {
    final TextEditingController amountController = TextEditingController(
      text: option.balance.abs().toStringAsFixed(2)
    );
    final isPositive = option.balance >= 0;
    final maxAmount = option.balance.abs();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Settlement Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPositive 
                  ? 'You owe ${option.name} ${_activity!['currency'] ?? '\$'}${maxAmount.toStringAsFixed(2)}'
                  : '${option.name} owes you ${_activity!['currency'] ?? '\$'}${maxAmount.toStringAsFixed(2)}'
            ),
            const SizedBox(height: 16),
            const Text('How much would you like to settle?'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: _activity!['currency'] ?? '\$',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter an amount between 0 and ${maxAmount.toStringAsFixed(2)}',
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
                  SnackBar(content: Text('Amount cannot exceed ${maxAmount.toStringAsFixed(2)}')),
                );
                return;
              }
              Navigator.pop(context);
              _createSettlementTransaction(option.name, isPositive ? amount : -amount);
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_activity?['name'] ?? 'Activity Details'),
        backgroundColor: const Color(0xFFF5A9C1),
        actions: [
          IconButton(
  icon: Icon(Icons.edit),
  onPressed: () async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditActivityScreen(activityData: _activity!),
      ),
    );

    // Check if update happened, then reload
    if (updated == true) {
      _loadActivityData();
    }
  },
),


        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _activity == null
              ? const Center(child: Text('Activity not found'))
              : RefreshIndicator(
                onRefresh: _loadActivityData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activity Header
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
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.hiking,
                                      color: AppTheme.primaryColor,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _activity!['name'],
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.file_download),
                                              onPressed: _generateActivityReport,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          DateFormat('MMMM d, yyyy').format(
                                            (_activity!['createdAt']
                                                    as Timestamp)
                                                .toDate(),
                                          ),
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              if (_activity!['description'] != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _activity!['description'],
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total spent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${(_activity!['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildBalancesCard(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => AddExpenseScreen(
                                        activityId: _activity!['id'],
                                        activityName: _activity!['name'],
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _transactions.isEmpty
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                'No transactions yet',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              return _buildTransactionItem(
                                _transactions[index],
                              );
                            },
                          ),
                      Padding(padding: const EdgeInsets.only(bottom: 70.0)),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => AddExpenseScreen(
                    activityId: _activity!['id'],
                    activityName: _activity!['name'],
                  ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
