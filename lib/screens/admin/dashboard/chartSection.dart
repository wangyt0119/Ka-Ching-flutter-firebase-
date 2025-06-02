import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';

class ChartSection extends StatelessWidget {
  final bool isDaily;
  final VoidCallback onToggle;

  const ChartSection({
    Key? key,
    required this.isDaily,
    required this.onToggle,
  }) : super(key: key);

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
                  isDaily ? 'Daily' : 'Weekly',
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                            reservedSize: isMobile ? 25 : 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _getBottomTitle(value.toInt()),
                                style: TextStyle(fontSize: isMobile ? 10 : 12),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      return 'W${value + 1}';
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
      return _getWeeklyActiveUsers();
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
        final dayOfWeek = (createdAt.weekday - 1) % 7; // Convert to 0-6 (Mon-Sun)
        
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

  Stream<List<FlSpot>> _getWeeklyActiveUsers() {
    return FirebaseFirestore.instance
        .collectionGroup('activities')
        .where('createdAt', isGreaterThanOrEqualTo: _getStartOfMonth().toDate())
        .snapshots()
        .map((snapshot) {
      // Group activities by week
      Map<int, Set<String>> weeklyUsers = {};
      final startOfMonth = _getStartOfMonth().toDate();
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final weekNumber = ((createdAt.difference(startOfMonth).inDays) / 7).floor();
        
        if (weekNumber >= 0 && weekNumber < 4) {
          if (!weeklyUsers.containsKey(weekNumber)) {
            weeklyUsers[weekNumber] = <String>{};
          }
          
          // Add unique user IDs
          if (data['members'] != null) {
            for (var member in data['members']) {
              if (member['id'] != null) {
                weeklyUsers[weekNumber]!.add(member['id']);
              }
            }
          }
          
          if (data['createdBy'] != null) {
            weeklyUsers[weekNumber]!.add(data['createdBy']);
          }
        }
      }
      
      // Convert to FlSpot list
      return List.generate(4, (index) {
        final userCount = weeklyUsers[index]?.length ?? 0;
        return FlSpot(index.toDouble(), userCount.toDouble());
      });
    });
  }

  Timestamp _getStartOfWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return Timestamp.fromDate(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day));
  }

  Timestamp _getStartOfMonth() {
    final now = DateTime.now();
    return Timestamp.fromDate(DateTime(now.year, now.month, 1));
  }
}