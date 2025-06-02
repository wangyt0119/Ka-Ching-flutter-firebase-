import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';

class ChartSection extends StatelessWidget {
  final bool isDaily;
  final VoidCallback onToggle;

  const ChartSection({Key? key, required this.isDaily, required this.onToggle})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'User Activity',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  isDaily ? 'Daily' : 'Monthly',
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
                Switch(
                  value: !isDaily,
                  onChanged: (_) => onToggle(),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SizedBox(
              height: isMobile ? 200 : 250,
              child: StreamBuilder<List<FlSpot>>(
                stream: _getActivityData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    print('Chart data error: ${snapshot.error}');
                    print('Error details: ${snapshot.stackTrace}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(height: 8),
                          Text(
                            'Error loading chart data',
                            style: TextStyle(color: Colors.red),
                          ),
                          if (snapshot.error != null)
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    );
                  }

                  final spots = snapshot.data ?? _getDefaultSpots();

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: isMobile ? 30 : 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(fontSize: isMobile ? 10 : 12),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: isMobile ? 25 : 30,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 == 0 && value >= 0 && value <= 6) {
                                return Text(
                                  _getBottomTitle(value.toInt()),
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                  ),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: isMobile ? 2 : 3,
                          dotData: FlDotData(show: !isMobile),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getBottomTitle(int value) {
  if (isDaily) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return value < days.length ? days[value] : '';
  } else {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return value >= 0 && value < months.length ? months[value] : '';
  }
}


  List<FlSpot> _getDefaultSpots() {
    if (isDaily) {
      return List.generate(7, (index) => FlSpot(index.toDouble(), 0));
    } else {
      return List.generate(4, (index) => FlSpot(index.toDouble(), 0));
    }
  }

  Stream<List<FlSpot>> _getActivityData() {
    if (isDaily) {
      return _getDailyActiveUsers();
    } else {
      return _getMonthlyActiveUsers();
    }
  }

  Stream<List<FlSpot>> _getDailyActiveUsers() {
    return FirebaseFirestore.instance
        .collectionGroup('activities')
        .where('createdAt', isGreaterThanOrEqualTo: _getStartOfWeek().toDate())
        .snapshots()
        .map((snapshot) {
          // Group activities by day of week
          Map<int, Set<String>> dailyUsers = {};

          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = (data['createdAt'] as Timestamp).toDate();
            final dayOfWeek =
                (createdAt.weekday - 1) % 7; // Convert to 0-6 (Mon-Sun)

            if (!dailyUsers.containsKey(dayOfWeek)) {
              dailyUsers[dayOfWeek] = <String>{};
            }

            // Add unique user IDs who participated in activities
            if (data['members'] != null) {
              for (var member in data['members']) {
                if (member['id'] != null) {
                  dailyUsers[dayOfWeek]!.add(member['id']);
                }
              }
            }

            // Also count activity creator
            if (data['createdBy'] != null) {
              dailyUsers[dayOfWeek]!.add(data['createdBy']);
            }
          }

          // Convert to FlSpot list
          return List.generate(7, (index) {
            final userCount = dailyUsers[index]?.length ?? 0;
            return FlSpot(index.toDouble(), userCount.toDouble());
          });
        });
  }

  Stream<List<FlSpot>> _getMonthlyActiveUsers() {
  return FirebaseFirestore.instance
      .collectionGroup('activities')
      .where('createdAt', isGreaterThanOrEqualTo: _getStartOfYear().toDate())
      .snapshots()
      .map((snapshot) {
    Map<int, Set<String>> monthlyUsers = {};
    final startOfYear = _getStartOfYear().toDate();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final month = createdAt.month - 1; // Jan = 0, Dec = 11

      if (month >= 0 && month < 12) {
        monthlyUsers.putIfAbsent(month, () => <String>{});

        if (data['members'] != null) {
          for (var member in data['members']) {
            if (member['id'] != null) {
              monthlyUsers[month]!.add(member['id']);
            }
          }
        }

        if (data['createdBy'] != null) {
          monthlyUsers[month]!.add(data['createdBy']);
        }
      }
    }

    return List.generate(12, (index) {
      final userCount = monthlyUsers[index]?.length ?? 0;
      return FlSpot(index.toDouble(), userCount.toDouble());
    });
  });
}

Timestamp _getStartOfYear() {
  final now = DateTime.now();
  return Timestamp.fromDate(DateTime(now.year, 1, 1));
}

  Timestamp _getStartOfWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return Timestamp.fromDate(
      DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
    );
  }

  // Timestamp _getStartOfMonth() {
  //   final now = DateTime.now();
  //   return Timestamp.fromDate(DateTime(now.year, now.month, 1));
  // }
}
