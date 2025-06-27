import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../../theme/app_theme.dart';
import '../../providers/currency_provider.dart';
import '../transactions/add_expense_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import 'edit_activity_screen.dart';
import 'total_spent.dart';
import 'settleup.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final String? ownerId;
  final String title;

  const ActivityDetailScreen({
    Key? key,
    required this.activityId,
    this.ownerId,
    required this.title,
  }) : super(key: key);

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>> _transactions = [];
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _loadActivityData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ownerUid = widget.ownerId ?? user.uid;

      // ── Activity -----------------------------------------------------------------
      final activityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('activities')
          .doc(widget.activityId)
          .get();

      if (!activityDoc.exists) {
        setState(() {
          _isLoading = false;
          _activity = null;
        });
        return;
      }

      final activityData = activityDoc.data()!;
      activityData['id'] = activityDoc.id;
      _isCreator = activityData['createdBy'] == user.uid;

      // ── Transactions -------------------------------------------------------------
      final txnSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('activities')
          .doc(widget.activityId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      final txns = txnSnapshot.docs
          .map((d) => {...d.data(), 'id': d.id})
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        _activity = activityData;
        _transactions = txns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading activity data: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PDF EXPORT
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _generateActivityReport() async {
    if (_activity == null) return;

    final pdf = pw.Document();

    // Get total amounts by currency
    Map<String, double> totalAmountsByCurrency = {};
  
    // Calculate totals from transactions
    for (var transaction in _transactions) {
      if (transaction['is_settlement'] == true) continue; // Skip settlements
    
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      final currency = transaction['currency'] ?? 'USD';
    
      totalAmountsByCurrency[currency] = (totalAmountsByCurrency[currency] ?? 0.0) + amount;
    }

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _activity!['name'],
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Date: ${DateFormat('MMMM d, yyyy').format((_activity!['createdAt'] as Timestamp).toDate())}',
            ),
            if ((_activity!['description'] ?? '').toString().trim().isNotEmpty)
              pw.Column(children: [
                pw.SizedBox(height: 5),
                pw.Text('Description: ${_activity!['description']}'),
              ]),
            pw.SizedBox(height: 10),
            
            // Display total amounts for each currency
            ...totalAmountsByCurrency.entries.map((entry) {
              final currencyCode = entry.key;
              final amount = entry.value;
            
              // Get currency symbol
              String currencySymbol = currencyCode;
              if (currencyCode == 'GBP') currencySymbol = '£';
              if (currencyCode == 'JPY') currencySymbol = '¥';
              if (currencyCode == 'CNY') currencySymbol = '¥';
              if (currencyCode == 'INR') currencySymbol = '₹';
              if (currencyCode == 'MYR') currencySymbol = 'RM';
              if (currencyCode == 'SGD') currencySymbol = 'S\$';
              if (currencyCode == 'IDR') currencySymbol = 'Rp';
              if (currencyCode == 'USD') currencySymbol = '\$';
              if (currencyCode == 'EUR') currencySymbol = '€';
              

              return pw.Text(
                'Total Amount: $currencySymbol${amount.toStringAsFixed(2)} ($currencyCode)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              );
            }).toList(),
            
            pw.Divider(),
            pw.Text(
              'Transactions',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            
            // Transactions table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Date
                1: const pw.FlexColumnWidth(3), // Title
                2: const pw.FlexColumnWidth(1.5), // Amount
                3: const pw.FlexColumnWidth(2), // Paid By
              },
              children: [
                // Table header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Paid By', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                
                // Transaction rows
                ..._transactions.where((txn) => txn['is_settlement'] != true).map((txn) {
                  // Format date
                  String dateStr = 'Unknown';
                  final timestamp = txn['timestamp'] as Timestamp?;
                  final dateRaw = txn['date'];
                  
                  if (timestamp != null) {
                    dateStr = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
                  } else if (dateRaw is String) {
                    try {
                      final parsedDate = DateTime.tryParse(dateRaw) ?? 
                                        DateFormat('MMM dd, yyyy').tryParse(dateRaw);
                      if (parsedDate != null) {
                        dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
                      } else {
                        dateStr = dateRaw;
                      }
                    } catch (e) {
                      dateStr = dateRaw;
                    }
                  }
                  
                  // Get amount with currency
                  final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
                  final currency = txn['currency'] ?? 'USD';
                  
                  // Get currency symbol
                  String currencySymbol = currency;
                  if (currency == 'USD') currencySymbol = '\$';
                  if (currency == 'MYR') currencySymbol = 'RM';
                  if (currency == 'EUR') currencySymbol = '€';
                  if (currency == 'GBP') currencySymbol = '£';
                  
                  final amountStr = '$currencySymbol${amount.toStringAsFixed(2)}';
                  
                  // Get paid by
                  final paidBy = txn['paid_by'] ?? 'Unknown';
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(dateStr),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(txn['title'] ?? 'Untitled'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(amountStr),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(paidBy),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            
            // Add detailed transaction information
            pw.SizedBox(height: 20),
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            
            ..._transactions.where((txn) => txn['is_settlement'] != true).map((txn) {
              // Format date
              String dateStr = 'Unknown';
              final timestamp = txn['timestamp'] as Timestamp?;
              final dateRaw = txn['date'];
              
              if (timestamp != null) {
                dateStr = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
              } else if (dateRaw is String) {
                try {
                  final parsedDate = DateTime.tryParse(dateRaw) ?? 
                                    DateFormat('MMM dd, yyyy').tryParse(dateRaw);
                  if (parsedDate != null) {
                    dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
                  } else {
                    dateStr = dateRaw;
                  }
                } catch (e) {
                  dateStr = dateRaw;
                }
              }
              
              // Get amount with currency
              final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
              final currency = txn['currency'] ?? 'USD';
              
              // Get currency symbol
              String currencySymbol = currency;
              if (currency == 'USD') currencySymbol = '\$';
              if (currency == 'MYR') currencySymbol = 'RM';
              if (currency == 'EUR') currencySymbol = '€';
              if (currency == 'GBP') currencySymbol = '£';
              
              final amountStr = '$currencySymbol${amount.toStringAsFixed(2)}';
              
              // Get participants
              final participants = List<String>.from(txn['participants'] ?? []);
              final participantsStr = participants.join(', ');
              
              // Get split method
              final split = txn['split'] ?? 'equally';
              
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Divider(),
                  pw.Text(
                    txn['title'] ?? 'Untitled',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Date: $dateStr'),
                      pw.Text('Amount: $amountStr'),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text('Paid by: ${txn['paid_by'] ?? 'Unknown'}'),
                  pw.SizedBox(height: 3),
                  pw.Text('Category: ${txn['category'] ?? 'Uncategorized'}'),
                  if ((txn['description'] ?? '').toString().isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text('Description: ${txn['description']}'),
                  ],
                  pw.SizedBox(height: 3),
                  pw.Text('Split: $split'),
                  pw.SizedBox(height: 3),
                  pw.Text('Participants: $participantsStr'),
                  pw.SizedBox(height: 10),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    final tempFile = XFile.fromData(
      bytes,
      name: '${_activity!['name']}_report.pdf',
      mimeType: 'application/pdf',
    );
    await Share.shareXFiles([tempFile],
        text: 'Activity Report: ${_activity!['name']}');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SUMMARY CARD
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null || _activity == null) return const SizedBox();

    // Get both regular balances and balances by currency
    final balances = _activity!['balances'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    final balancesByCurrency = _activity!['balances_by_currency'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    
    if (balances.isEmpty && balancesByCurrency.isEmpty) return const SizedBox();

    // Robust identity matching
    final uid = user.uid;
    final email = user.email ?? '';
    final name = user.displayName ?? '';
    bool isSelf(String key) => key == uid || key == email || key == name;

    final defaultCurrency = _activity!['currency'] ?? 'USD';
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

    final List<Widget> summaryItems = [];

    // Helper function to get name from key
    String _getNameFromKey(String key) {
      final members = _activity!['members'] as List<dynamic>? ?? [];
      for (final m in members) {
        if (m['id'] == key || m['email'] == key) {
          return m['name'] ?? key; // fallback to key if name is missing
        }
      }
      return key;
    }

    // Process balances by currency
    balancesByCurrency.forEach((currency, currencyBalances) {
      final Map<String, dynamic> balancesForCurrency = Map<String, dynamic>.from(currencyBalances);
      
      if (balancesForCurrency.isEmpty) return;
      
      final currencyObj = currencyProvider.getCurrencyByCode(currency) ?? 
                         currencyProvider.getCurrencyByCode(defaultCurrency) ??
                         currencyProvider.selectedCurrency;
      
      final List<Widget> currencyItems = [];
      
      balancesForCurrency.forEach((key, value) {
        final double amount = (value as num).toDouble();
        
        // Skip if self (by uid or email)
        if (isSelf(key)) return;
        
        final name = _getNameFromKey(key);
        
        if (amount < 0) {
          // They owe you
          currencyItems.add(
            Text(
              '$name owes you ${currencyObj.symbol}${amount.abs().toStringAsFixed(2)} (${currencyObj.code})',
              style: const TextStyle(color: Colors.green),
            ),
          );
        } else if (amount > 0) {
          // You owe them
          currencyItems.add(
            Text(
              'You owe $name ${currencyObj.symbol}${amount.toStringAsFixed(2)} (${currencyObj.code})',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
      });
      
      if (currencyItems.isNotEmpty) {
        // Add currency header if there are multiple currencies
        if (balancesByCurrency.length > 1) {
          summaryItems.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                '${currencyObj.code} Balances:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
        
        summaryItems.addAll(currencyItems);
        
        // Add separator if not the last currency
        if (currency != balancesByCurrency.keys.last && currencyItems.isNotEmpty) {
          summaryItems.add(const SizedBox(height: 8));
        }
      }
    });

    // If no items were added from balances_by_currency, fall back to the old balances
    if (summaryItems.isEmpty) {
      final List<Widget> youOwe = [];
      final List<Widget> peopleOweYou = [];
      
      balances.forEach((key, value) {
        final double amount = (value as num).toDouble();
        
        // Skip if self (by uid or email)
        if (isSelf(key)) return;
        
        final name = _getNameFromKey(key);
        
        if (amount < 0) {
          // They owe you
          peopleOweYou.add(
            Text(
              '$name owes you $defaultCurrency${amount.abs().toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green),
            ),
          );
        } else if (amount > 0) {
          // You owe them
          youOwe.add(
            Text(
              'You owe $name $defaultCurrency${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
      });
      
      summaryItems.addAll(youOwe);
      summaryItems.addAll(peopleOweYou);
    }

    if (summaryItems.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...summaryItems,
        ],
      ),
    );
  }

  Widget _buildSettleUpButton() {
    if (_activity == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SettleUpButton(
        activity: _activity!,
        activityId: widget.activityId,
        ownerId: widget.ownerId,
        refreshActivity: _loadActivityData,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TRANSACTION ITEM
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildTransactionItem(Map<String, dynamic> txn) {
    final icon = _getCategoryIcon(txn['category']);
    final user = FirebaseAuth.instance.currentUser;

    final paidById = txn['paid_by_id'];
    final paidBy = txn['paid_by'] ?? 'Unknown';

    final isCurrentUserPayer =
        (paidById != null && paidById == user?.uid) ||
            paidBy == user?.displayName ||
            paidBy == user?.email;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(
                transactionId: txn['id'],
                activityId: widget.activityId,
                ownerId: widget.ownerId,
              ),
            ),
          );
          _loadActivityData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.deepPurple, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Paid by ${isCurrentUserPayer ? 'You' : paidBy}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${txn['currency'] ?? '\$'}${(txn['amount'] ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy')
                        .format((txn['timestamp'] as Timestamp).toDate()),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'accommodation':
        return Icons.hotel;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.receipt;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFF5A9C1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _activity?['name'] ?? 'Activity Details',
          style:
              const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: accent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TotalSpent(
                    activityId: widget.activityId,
                    ownerUid: _isCreator ? user.uid : widget.ownerId!,
                    activityData: _activity!,
                  ),
                ),
              );
              if (updated == true) _loadActivityData();
            },
          ),
          if (_isCreator)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditActivityScreen(activityData: _activity!),
                  ),
                );
                if (updated == true) _loadActivityData();
              },
            ),
        ],
      ),

      // ── BODY ────────────────────────────────────────────────────────────────
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activity == null
              ? const Center(child: Text('Activity not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── ACTIVITY HEADER CARD ───────────────────────────────
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.group,
                                        color: Color(0xFFF5A9C1), size: 28),
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
                                              icon:
                                                  const Icon(Icons.file_download),
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
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if ((_activity!['description'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _activity!['description'],
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                              const SizedBox(height: 8),
                              const Divider(
                                color: AppTheme.dividerColor,
                                thickness: 1.5,
                              ),
                              _buildSummaryCard(),
                              _buildSettleUpButton(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                     
                      // ── TRANSACTIONS LIST ────────────────────────────────
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
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => AddExpenseScreen(
                                        activityId: _activity!['id'],
                                        activityName: _activity!['name'],
                                        ownerId: widget.ownerId,
                                      ),
                                    ),
                                  )
                                  .then((_) => _loadActivityData());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _transactions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No transactions yet',
                                  style:
                                      TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _transactions.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (_, i) =>
                                  _buildTransactionItem(_transactions[i]),
                            ),
                      const Padding(padding: EdgeInsets.only(bottom: 70)),
                    ],
                  ),
                ),

      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(
                    activityId: _activity!['id'],
                    activityName: _activity!['name'],
                    ownerId: widget.ownerId,
                  ),
                ),
              )
              .then((_) => _loadActivityData());
        },
      ),
    );
  }
}
