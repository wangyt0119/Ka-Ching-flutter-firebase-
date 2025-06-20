import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../theme/app_theme.dart';

class TotalSpent extends StatefulWidget {
  final String activityId;
  final String ownerUid;
  final Map<String, dynamic> activityData;

  const TotalSpent({
    super.key,
    required this.activityId,
    required this.ownerUid,
    required this.activityData,
  });

  @override
  State<TotalSpent> createState() => _TotalSpentState();
}

class _TotalSpentState extends State<TotalSpent> with SingleTickerProviderStateMixin {
  int _selectedYear = DateTime.now().year;
  String _selectedCurrency = 'MYR'; // Default currency
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent     = const Color(0xFFF5A9C1);
    final accentDark = const Color(0xFFE91E63);

    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Helper function to format amount with its original currency
    String formatWithOriginalCurrency(double amount, String currencyCode) {
      final currency = currencyProvider.getCurrencyByCode(currencyCode);
      if (currency != null) {
        // Format using the currency's symbol
        final formattedAmount = amount.toStringAsFixed(2);
        return '${currency.symbol}$formattedAmount';
      }
      // Fallback formatting
      return '$currencyCode ${amount.toStringAsFixed(2)}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Total Spending',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _buildYearPicker(accent),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Categories'),
          ],
        ),
      ),

      // ── MAIN BODY ────────────────────────────────────────────────────────────
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlyView(context, accent, accentDark, formatWithOriginalCurrency),
          _buildCategoryView(context, accent, accentDark, formatWithOriginalCurrency),
        ],
      ),
    );
  }

  // ── COMPONENTS ──────────────────────────────────────────────────────────────
  Widget _buildYearPicker(Color accent) => Container(
        margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.ownerUid)
                .collection('activities')
                .doc(widget.activityId)
                .collection('transactions')
                .snapshots(),
            builder: (context, snapshot) {
              final years = <int>{DateTime.now().year};
              if (snapshot.hasData) {
                for (final d in snapshot.data!.docs) {
                  final raw = d['date'] ?? d['timestamp'];
                  DateTime? dt;
                  if (raw is Timestamp) dt = raw.toDate();
                  if (raw is String) {
                    dt = DateTime.tryParse(raw) ??
                         DateFormat('MMM dd, yyyy').tryParse(raw);
                  }
                  if (dt != null) years.add(dt.year);
                }
              }
              final items = years.toList()..sort((a, b) => b.compareTo(a));
              if (!items.contains(_selectedYear)) _selectedYear = items.first;

              return DropdownButton<int>(
                value: _selectedYear,
                iconEnabledColor: Colors.white,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                items: [
                  for (final y in items)
                    DropdownMenuItem(
                      value: y,
                      child: Text(
                        '$y',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                ],
                onChanged: (v) => setState(() => _selectedYear = v!),
              );
            },
          ),
        ),
      );

  Widget _summaryCardsByCurrency(
    Color accent, 
    Color accentDark,
    Map<String, double> totalSpentByCurrency,
    Map<String, double> yourShareByCurrency,
    String Function(double, String) formatWithOriginalCurrency
  ) {
    return Column(
      children: [
        // Total Spent and My Spending in same row
        Row(
          children: [
            // Total Spent Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.payments_outlined, color: accent, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Total Spent',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500
                            )
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (totalSpentByCurrency.isEmpty)
                      Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600]
                        )
                      )
                    else
                      ...totalSpentByCurrency.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          formatWithOriginalCurrency(entry.value, entry.key),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800]
                          )
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // My Spending Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentDark.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person_outline, color: accentDark, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'My Payments',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500
                            )
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (yourShareByCurrency.isEmpty)
                      Text(
                        'No payments yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600]
                        )
                      )
                    else
                      ...yourShareByCurrency.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          formatWithOriginalCurrency(entry.value, entry.key),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800]
                          )
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color accent, Color accentDark) => Row(
  children: [
    Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // stay aligned to left
          children: [
            // Current Month
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: accentDark,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Current Month',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 24), 

            // Other Months
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Other Months',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);

  Widget _chartCard(
    List<BarChartGroupData> bars, 
    double maxAmount,
    String selectedCurrency,
    String Function(double, String) formatWithOriginalCurrency,
    List<String> availableCurrencies,
    Color accent
  ) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 24, color: Color(0xFFF5A9C1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Monthly Spending',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)
                  ),
                ),
                // Currency Selector
                if (availableCurrencies.length > 1)
                  _buildCurrencySelector(availableCurrencies, accent),
              ],
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.4,
              child: BarChart(
                BarChartData(
                  barGroups: bars,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.grey[800]!,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, _, rod, __) {
                        final month =
                            DateFormat('MMMM').format(DateTime(0, group.x + 1));
                        return BarTooltipItem(
                          '$month\n${formatWithOriginalCurrency(rod.toY, selectedCurrency)}',
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 100,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM').format(DateTime(0, value.toInt() + 1)),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildCurrencySelector(List<String> availableCurrencies, Color accent) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCurrency,
          iconEnabledColor: accent,
          dropdownColor: Colors.white,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          items: availableCurrencies.map((currencyCode) {
            final currency = currencyProvider.getCurrencyByCode(currencyCode);
            final displayText = currency != null 
                ? '${currency.symbol} $currencyCode'
                : currencyCode;
            
            return DropdownMenuItem(
              value: currencyCode,
              child: Text(
                displayText,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newCurrency) {
            if (newCurrency != null) {
              setState(() {
                _selectedCurrency = newCurrency;
              });
            }
          },
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────
  Widget _centerMessage(String msg) => Center(
        child: Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey[600])),
      );

  Widget _loading(Color accent) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accent), strokeWidth: 3),
            const SizedBox(height: 16),
            Text('Loading spending data...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );

  Widget _buildMonthlyView(
    BuildContext context, 
    Color accent, 
    Color accentDark, 
    String Function(double, String) formatWithOriginalCurrency
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ownerUid)
          .collection('activities')
          .doc(widget.activityId)
          .collection('transactions')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _centerMessage('Something went wrong\n${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return _loading(accent);
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _centerMessage('No transactions yet');
        }

        // ── AGGREGATE BY CURRENCY ──
        final monthTotalsByCurrency = <String, List<double>>{};
        final totalSpentByCurrency = <String, double>{};
        final yourShareByCurrency = <String, double>{};
        final uid = FirebaseAuth.instance.currentUser?.uid;

        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          if (data['is_settlement'] == true) continue;

          // Parse date (Timestamp or String)
          final rawDate = data['date'] ?? data['timestamp'];
          DateTime? txDate;
          if (rawDate is Timestamp) {
            txDate = rawDate.toDate();
          } else if (rawDate is String) {
            txDate = DateTime.tryParse(rawDate) ??
                     DateFormat('MMM dd, yyyy').tryParse(rawDate);
          }
          if (txDate == null || txDate.year != _selectedYear) continue;

          // Use transaction's original currency
          final rawAmt = (data['amount'] ?? 0).toDouble();
          final currencyCode = data['currency'] ?? 'USD';
          final paidBy = data['paid_by'] ?? '';
          final paidById = data['paid_by_id'];
          
          // Initialize currency tracking if not exists
          if (!monthTotalsByCurrency.containsKey(currencyCode)) {
            monthTotalsByCurrency[currencyCode] = List<double>.filled(12, 0);
            totalSpentByCurrency[currencyCode] = 0;
            yourShareByCurrency[currencyCode] = 0;
          }
          
          // Add to monthly total
          if (txDate != null) {
            final monthIndex = txDate.month - 1;
            monthTotalsByCurrency[currencyCode]![monthIndex] += rawAmt;
          }
          
          // Add to total spent
          totalSpentByCurrency[currencyCode] = 
              (totalSpentByCurrency[currencyCode] ?? 0) + rawAmt;
          
          // Check if current user paid for this transaction
          final isCurrentUserPayer = 
              (paidById != null && paidById == uid) || 
              paidBy == FirebaseAuth.instance.currentUser?.displayName || 
              paidBy == FirebaseAuth.instance.currentUser?.email;
              
          // If current user paid for this transaction, add to their payments
          if (isCurrentUserPayer) {
            yourShareByCurrency[currencyCode] = 
                (yourShareByCurrency[currencyCode] ?? 0) + rawAmt;
          }
        }

        // Get available currencies (only currencies that have been used)
        final availableCurrencies = monthTotalsByCurrency.keys.toList()..sort();
        
        // Set default currency if current selection is not available
        if (availableCurrencies.isNotEmpty && !availableCurrencies.contains(_selectedCurrency)) {
          _selectedCurrency = availableCurrencies.contains('MYR') ? 'MYR' : availableCurrencies.first;
        }

        // Get data for selected currency
        final monthTotals = monthTotalsByCurrency[_selectedCurrency] ?? List<double>.filled(12, 0);
        final maxAmount = monthTotals.isEmpty ? 0.0 : monthTotals.reduce((a, b) => a > b ? a : b);
        
        final bars = List<BarChartGroupData>.generate(12, (i) {
          final isCurrentMonth =
              i == DateTime.now().month - 1 && _selectedYear == DateTime.now().year;
          final hasData = monthTotals[i] > 0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: monthTotals[i],
                color: isCurrentMonth
                    ? accentDark
                    : hasData
                        ? accent
                        : Colors.grey[200],
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        });

        // ── UI ──
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryCardsByCurrency(
                  accent, 
                  accentDark, 
                  totalSpentByCurrency, 
                  yourShareByCurrency,
                  formatWithOriginalCurrency
                ),
                const SizedBox(height: 16),
                _legend(accent, accentDark),
                const SizedBox(height: 24),
                _chartCard(
                  bars, 
                  maxAmount, 
                  _selectedCurrency, 
                  formatWithOriginalCurrency,
                  availableCurrencies,
                  accent
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryView(
    BuildContext context, 
    Color accent, 
    Color accentDark, 
    String Function(double, String) formatWithOriginalCurrency
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ownerUid)
          .collection('activities')
          .doc(widget.activityId)
          .collection('transactions')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _centerMessage('Something went wrong\n${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return _loading(accent);
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _centerMessage('No transactions yet');
        }

        // ── AGGREGATE BY CATEGORY AND CURRENCY ──
        final categoryTotalsByCurrency = <String, Map<String, double>>{};
        final totalSpentByCurrency = <String, double>{};
        final uid = FirebaseAuth.instance.currentUser?.uid;

        // Define categories
        final categories = [
          'Food', 
          'Beverage', 
          'Entertainment', 
          'Transportation', 
          'Shopping', 
          'Travel', 
          'Utilities', 
          'Other'
        ];

        // Initialize category maps for each currency
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          if (data['is_settlement'] == true) continue;

          // Parse date (Timestamp or String)
          final rawDate = data['date'] ?? data['timestamp'];
          DateTime? txDate;
          if (rawDate is Timestamp) {
            txDate = rawDate.toDate();
          } else if (rawDate is String) {
            txDate = DateTime.tryParse(rawDate) ??
                     DateFormat('MMM dd, yyyy').tryParse(rawDate);
          }
          if (txDate == null || txDate.year != _selectedYear) continue;

          // Use transaction's original currency
          final rawAmt = (data['amount'] ?? 0).toDouble();
          final currencyCode = data['currency'] ?? 'USD';
          final category = data['category'] ?? 'Other';

          // Initialize currency tracking if not exists
          if (!categoryTotalsByCurrency.containsKey(currencyCode)) {
            categoryTotalsByCurrency[currencyCode] = {};
            for (final cat in categories) {
              categoryTotalsByCurrency[currencyCode]![cat] = 0.0;
            }
            totalSpentByCurrency[currencyCode] = 0;
          }
          
          // Add to category total
          categoryTotalsByCurrency[currencyCode]![category] = 
              (categoryTotalsByCurrency[currencyCode]![category] ?? 0) + rawAmt;
          
          // Add to total spent
          totalSpentByCurrency[currencyCode] = 
              (totalSpentByCurrency[currencyCode] ?? 0) + rawAmt;
        }

        // Get available currencies (only currencies that have been used)
        final availableCurrencies = categoryTotalsByCurrency.keys.toList()..sort();
        
        // Set default currency if current selection is not available
        if (availableCurrencies.isNotEmpty && !availableCurrencies.contains(_selectedCurrency)) {
          _selectedCurrency = availableCurrencies.contains('MYR') ? 'MYR' : availableCurrencies.first;
        }

        // Get data for selected currency
        final categoryTotals = categoryTotalsByCurrency[_selectedCurrency] ?? {};
        
        // Filter out categories with zero spending
        final nonZeroCategories = categories.where((cat) => 
            (categoryTotals[cat] ?? 0) > 0).toList();
        
        // Prepare data for pie chart
        final pieChartSections = <PieChartSectionData>[];
        final categoryColors = {
          'Food': Colors.red,
          'Beverage': Colors.blue,
          'Entertainment': Colors.purple,
          'Transportation': Colors.orange,
          'Shopping': Colors.green,
          'Travel': Colors.teal,
          'Utilities': Colors.amber,
          'Other': Colors.grey,
        };
        
        double totalAmount = 0;
        for (final cat in nonZeroCategories) {
          totalAmount += categoryTotals[cat] ?? 0;
        }
        
        for (int i = 0; i < nonZeroCategories.length; i++) {
          final category = nonZeroCategories[i];
          final amount = categoryTotals[category] ?? 0;
          final percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0;
          
          pieChartSections.add(
            PieChartSectionData(
              color: categoryColors[category] ?? Colors.grey,
              value: amount,
              title: '${percentage.toStringAsFixed(1)}%',
              radius: 100,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          );
        }

        // ── UI ──
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Removed the summary cards
                _buildCategoryPieChart(
                  pieChartSections, 
                  nonZeroCategories, 
                  categoryTotals, 
                  categoryColors,
                  _selectedCurrency,
                  formatWithOriginalCurrency,
                  availableCurrencies,
                  accent
                ),
                const SizedBox(height: 24),
                _buildCategoryList(
                  nonZeroCategories,
                  categoryTotals,
                  categoryColors,
                  _selectedCurrency,
                  formatWithOriginalCurrency
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryPieChart(
    List<PieChartSectionData> sections,
    List<String> categories,
    Map<String, double> categoryTotals,
    Map<String, Color> categoryColors,
    String selectedCurrency,
    String Function(double, String) formatWithOriginalCurrency,
    List<String> availableCurrencies,
    Color accent
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, size: 24, color: Color(0xFFF5A9C1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Spending by Category',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)
                ),
              ),
              // Currency Selector
              if (availableCurrencies.length > 1)
                _buildCurrencySelector(availableCurrencies, accent),
            ],
          ),
          const SizedBox(height: 20),
          sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No categorized expenses yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : SizedBox(
                  height: 300,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // Handle touch events if needed
                        },
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
    List<String> categories,
    Map<String, double> categoryTotals,
    Map<String, Color> categoryColors,
    String selectedCurrency,
    String Function(double, String) formatWithOriginalCurrency
  ) {
    // Sort categories by amount (descending)
    categories.sort((a, b) => 
        (categoryTotals[b] ?? 0).compareTo(categoryTotals[a] ?? 0));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...categories.map((category) {
            final amount = categoryTotals[category] ?? 0;
            final color = categoryColors[category] ?? Colors.grey;
            
            // Get icon based on category
            IconData categoryIcon;
            switch (category) {
              case 'Food':
                categoryIcon = Icons.restaurant;
                break;
              case 'Beverage':
                categoryIcon = Icons.local_drink;
                break;
              case 'Entertainment':
                categoryIcon = Icons.movie;
                break;
              case 'Transportation':
                categoryIcon = Icons.directions_car;
                break;
              case 'Shopping':
                categoryIcon = Icons.shopping_bag;
                break;
              case 'Travel':
                categoryIcon = Icons.flight;
                break;
              case 'Utilities':
                categoryIcon = Icons.power;
                break;
              default:
                categoryIcon = Icons.category;
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(categoryIcon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    formatWithOriginalCurrency(amount, selectedCurrency),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
