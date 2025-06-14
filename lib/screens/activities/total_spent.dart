import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class _TotalSpentState extends State<TotalSpent> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFF5A9C1);
    final accentDark = const Color(0xFFE91E63);
    final currencyCode = widget.activityData['currency'] ?? 'MYR';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Total Spending',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // ── Enhanced Year-picker dropdown ──────────────────────────────────────
          Container(
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
                      final ts = (d['timestamp'] ?? d['date']) as Timestamp?;
                      if (ts != null) years.add(ts.toDate().year);
                    }
                  }
                  final items = years.toList()..sort((a, b) => b.compareTo(a));
                  if (!items.contains(_selectedYear)) _selectedYear = items.first;

                  return DropdownButton<int>(
                    value: _selectedYear,
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
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
          ),
        ],
      ),

      // ── Enhanced main body ─────────────────────────────────────────────────────
      body: StreamBuilder<QuerySnapshot>(
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snap.error}',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading spending data...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start adding expenses to see your spending overview',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // ── Data aggregation ─────────────────────────────────────────────────────
          final monthTotals = List<double>.filled(12, 0);
          double totalSpent = 0;
          double yourShare = 0;
          final uid = FirebaseAuth.instance.currentUser?.uid;

          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            if (data['is_settlement'] == true) continue;

            final ts = (data['timestamp'] ?? data['date']) as Timestamp?;
            if (ts == null || ts.toDate().year != _selectedYear) continue;

            final amt = (data['amount'] ?? 0).toDouble();
            final mIndex = ts.toDate().month - 1;

            monthTotals[mIndex] += amt;
            totalSpent += amt;
            if (data['paid_by'] == uid) yourShare += amt;
          }

          // ── Enhanced bar chart ─────────────────────────────────────────────────────
          final maxAmount = monthTotals.fold<double>(0, (a, b) => a > b ? a : b);
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
                          : Colors.grey[200]!,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          });

          String fmt(double v) =>
              NumberFormat.currency(symbol: currencyCode).format(v);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
                              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary cards ─────────────────────────────────────────────────────
                  Row(
                    children: [
                      // Total spent card
                      Expanded(
                        child: Container(
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.payments_outlined,
                                      color: accent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Spent',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                fmt(totalSpent),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Your share card
                      Expanded(
                        child: Container(
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: accentDark,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Share',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                fmt(yourShare),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalSpent == 0
                                    ? 'No spending yet'
                                    : '${(yourShare / totalSpent * 100).toStringAsFixed(1)}% of total',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Legend ─────────────────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        // Current month legend
                        Row(
                          children: [
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
                          ],
                        ),
                        const SizedBox(width: 24),
                        // Other months legend
                        Row(
                          children: [
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Chart card ─────────────────────────────────────────────────────
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
                            Icon(Icons.bar_chart, color: accent, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Monthly Spending',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$_selectedYear',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
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
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final month = DateFormat('MMMM').format(
                                      DateTime(0, group.x + 1),
                                    );
                                    return BarTooltipItem(
                                      '$month\n${fmt(rod.toY)}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 100,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey[200]!,
                                  strokeWidth: 1,
                                ),
                                drawVerticalLine: false,
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) => Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        DateFormat('MMM').format(
                                          DateTime(0, value.toInt() + 1),
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
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
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}