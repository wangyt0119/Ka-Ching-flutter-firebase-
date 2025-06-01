import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../auth_gate.dart';
import '../../../theme/app_theme.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  bool _isDaily = true; // For switching between daily and weekly view
  bool _isCollapsed = false; // For collapsing sidebar on mobile

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _DashboardPage(isDaily: _isDaily, onToggle: _toggleChartView),
      const _UsersPage(),
      const _ActivitiesPage(),
      const _ProfilePage(),
    ]);
  }

  void _toggleChartView() {
    setState(() {
      _isDaily = !_isDaily;
      _pages[0] = _DashboardPage(isDaily: _isDaily, onToggle: _toggleChartView);
    });
  }

  // Logout function
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          // Side Navigation
          _buildSideNavigation(isMobile),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top App Bar
                _buildTopAppBar(),
                
                // Page Content
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavigation(bool isMobile) {
    final sidebarWidth = _isCollapsed ? 70.0 : (isMobile ? 250.0 : 280.0);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: sidebarWidth,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (isMobile)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isCollapsed = !_isCollapsed;
                        });
                      },
                      icon: Icon(
                        _isCollapsed ? Icons.menu : Icons.menu_open,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            
            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.dashboard,
                    label: 'Dashboard',
                    isSelected: _selectedIndex == 0,
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.people,
                    label: 'Users',
                    isSelected: _selectedIndex == 1,
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.local_activity,
                    label: 'Activities',
                    isSelected: _selectedIndex == 2,
                  ),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.person,
                    label: 'Profile',
                    isSelected: _selectedIndex == 3,
                  ),
                  
                  // Divider
                  if (!_isCollapsed) ...[
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Logout Button
                  _buildNavItem(
                    index: -1,
                    icon: Icons.logout,
                    label: 'Logout',
                    isSelected: false,
                    isLogout: true,
                  ),
                ],
              ),
            ),
            
            // Footer
            if (!_isCollapsed)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isLogout) {
              _logout(context);
            } else {
              setState(() {
                _selectedIndex = index;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
                : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected 
                    ? AppTheme.primaryColor
                    : (isLogout ? Colors.red : Colors.grey[600]),
                  size: 24,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected 
                          ? AppTheme.primaryColor
                          : (isLogout ? Colors.red : Colors.grey[800]),
                        fontWeight: isSelected 
                          ? FontWeight.w600 
                          : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Text(
              _getPageTitle(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            
            // Admin User Info
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final user = snapshot.data!;
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          user.email?.substring(0, 1).toUpperCase() ?? 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            user.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Users Management';
      case 2:
        return 'Activities Management';
      case 3:
        return 'Profile Settings';
      default:
        return 'Admin Panel';
    }
  }
}

class _DashboardPage extends StatelessWidget {
  final bool isDaily;
  final VoidCallback onToggle;

  const _DashboardPage({required this.isDaily, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          const _StatisticsSection(),
          SizedBox(height: isDesktop ? 32 : 24),
          
          if (isDesktop) ...[
            // Desktop Layout - Side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Users Section
                const Expanded(
                  flex: 1,
                  child: _RecentUsersSection(),
                ),
                const SizedBox(width: 24),
                
                // Chart Section
                Expanded(
                  flex: 2,
                  child: _ChartSection(isDaily: isDaily, onToggle: onToggle),
                ),
              ],
            ),
          ] else ...[
            // Mobile Layout - Stacked
            const _RecentUsersSection(),
            const SizedBox(height: 24),
            _ChartSection(isDaily: isDaily, onToggle: onToggle),
          ],
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: isDesktop ? 20 : 16,
          mainAxisSpacing: isDesktop ? 20 : 16,
          childAspectRatio: isDesktop ? 2.5 : 1.5,
          children: [
            _buildStatCard('Total Users', _getTotalUsers(), Icons.people, Colors.blue, isDesktop),
            _buildStatCard('Activities', _getTotalActivities(), Icons.local_activity, Colors.green, isDesktop),
            _buildStatCard('Transactions', _getTotalTransactions(), Icons.receipt, Colors.orange, isDesktop),
            _buildStatCard('Active Today', _getActiveToday(), Icons.trending_up, Colors.purple, isDesktop),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, Widget value, IconData icon, Color color, bool isDesktop) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: isDesktop ? 
          // Desktop Layout - Horizontal
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    value,
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ) :
          // Mobile Layout - Vertical
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              value,
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _getTotalUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _getTotalActivities() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('activities').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _getTotalTransactions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('transactions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _getActiveToday() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('activities')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
        }
        
        Set<String> activeUsers = {};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['members'] != null) {
            for (var member in data['members']) {
              if (member['id'] != null) {
                activeUsers.add(member['id']);
              }
            }
          }
        }
        
        return Text(
          '${activeUsers.length}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        );
      },
    );
  }
}

class _RecentUsersSection extends StatelessWidget {
  const _RecentUsersSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Users',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading users: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: snapshot.data!.docs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = data['full_name']?.toString() ?? 'Unknown User';
                  final email = data['email']?.toString() ?? 'No email';
                  final role = data['role']?.toString() ?? 'user';
                  
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          email,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: role == 'admin' 
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              color: role == 'admin' ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      if (index < snapshot.data!.docs.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  final bool isDaily;
  final VoidCallback onToggle;

  const _ChartSection({required this.isDaily, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'User Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(isDaily ? 'Daily' : 'Weekly'),
                Switch(
                  value: !isDaily,
                  onChanged: (_) => onToggle(),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (isDaily) {
                            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            if (value >= 0 && value < days.length) {
                              return Text(days[value.toInt()]);
                            }
                          } else {
                            return Text('W${value.toInt() + 1}');
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateChartData(),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _generateChartData() {
    // Mock data - in a real app, you'd fetch this from Firebase
    if (isDaily) {
      return [
        const FlSpot(0, 12),
        const FlSpot(1, 18),
        const FlSpot(2, 15),
        const FlSpot(3, 22),
        const FlSpot(4, 28),
        const FlSpot(5, 25),
        const FlSpot(6, 20),
      ];
    } else {
      return [
        const FlSpot(0, 85),
        const FlSpot(1, 120),
        const FlSpot(2, 95),
        const FlSpot(3, 140),
      ];
    }
  }
}

class _UsersPage extends StatelessWidget {
  const _UsersPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Users Management\n(To be implemented)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

class _ActivitiesPage extends StatelessWidget {
  const _ActivitiesPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Activities Management\n(To be implemented)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Profile Settings\n(To be implemented)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}