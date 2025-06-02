import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../auth_gate.dart';
import '../../../theme/app_theme.dart';
import '../profile/profile_screen.dart';
import '../activity/activity_screen.dart';
import '../users/users_screen.dart';
import 'chartSection.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  bool _isDaily = true;
  bool _isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _DashboardPage(isDaily: _isDaily, onToggle: _toggleChartView),
      const UsersScreen(),
      const ActivityScreen(),
      const ProfileScreen(),
    ]);
  }

  void _toggleChartView() {
    setState(() {
      _isDaily = !_isDaily;
      _pages[0] = _DashboardPage(isDaily: _isDaily, onToggle: _toggleChartView);
    });
  }

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
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout(isTablet);
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _getPageTitle(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final user = snapshot.data!;
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.email?.substring(0, 1).toUpperCase() ?? 'A',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      drawer: _buildMobileDrawer(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDesktopLayout(bool isTablet) {
    return Scaffold(
      body: Row(
        children: [
          _buildSideNavigation(isTablet),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(0, Icons.dashboard, 'Dashboard'),
                _buildDrawerItem(1, Icons.people, 'Users'),
                _buildDrawerItem(2, Icons.local_activity, 'Activities'),
                _buildDrawerItem(3, Icons.person, 'Profile'),
                const Divider(height: 32),
                _buildDrawerItem(-1, Icons.logout, 'Logout', isLogout: true),
              ],
            ),
          ),
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
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String label, {bool isLogout = false}) {
    final isSelected = _selectedIndex == index && !isLogout;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected 
          ? AppTheme.primaryColor
          : (isLogout ? Colors.red : Colors.grey[600]),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected 
            ? AppTheme.primaryColor
            : (isLogout ? Colors.red : Colors.grey[800]),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context);
        if (isLogout) {
          _logout(context);
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_activity),
          label: 'Activities',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildSideNavigation(bool isTablet) {
    final sidebarWidth = isTablet ? 240.0 : 280.0;
    
    return Container(
      width: sidebarWidth,
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
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(0, Icons.dashboard, 'Dashboard', _selectedIndex == 0),
                _buildNavItem(1, Icons.people, 'Users', _selectedIndex == 1),
                _buildNavItem(2, Icons.local_activity, 'Activities', _selectedIndex == 2),
                _buildNavItem(3, Icons.person, 'Profile', _selectedIndex == 3),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(),
                ),
                const SizedBox(height: 20),
                _buildNavItem(-1, Icons.logout, 'Logout', false, isLogout: true),
              ],
            ),
          ),
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isSelected, {bool isLogout = false}) {
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
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatisticsSection(),
          SizedBox(height: isMobile ? 16 : (isTablet ? 20 : 32)),
          
          if (isMobile) ...[
            // Mobile Layout - Stacked
            ChartSection(isDaily: isDaily, onToggle: onToggle), // Changed from _ChartSection
            const SizedBox(height: 16),
            const _RecentUsersSection(),
          ] else if (isTablet) ...[
            // Tablet Layout - Stacked but with more spacing
            ChartSection(isDaily: isDaily, onToggle: onToggle), // Changed from _ChartSection
            const SizedBox(height: 20),
            const _RecentUsersSection(),
          ] else ...[
            // Desktop Layout - Side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 1,
                  child: _RecentUsersSection(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: ChartSection(isDaily: isDaily, onToggle: onToggle), // Changed from _ChartSection
                ),
              ],
            ),
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
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    int crossAxisCount;
    double childAspectRatio;
    double spacing;

    if (isMobile) {
      crossAxisCount = 2;
      childAspectRatio = 1.3;
      spacing = 12;
    } else if (isTablet) {
      crossAxisCount = 2;
      childAspectRatio = 2.0;
      spacing = 16;
    } else {
      crossAxisCount = 4;
      childAspectRatio = 2.5;
      spacing = 20;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: [
            _buildStatCard('Total Users', _getTotalUsers(), Icons.people, Colors.blue, isMobile, isTablet),
            _buildStatCard('Activities', _getTotalActivities(), Icons.local_activity, Colors.green, isMobile, isTablet),
            _buildStatCard('Transactions', _getTotalTransactions(), Icons.receipt, Colors.orange, isMobile, isTablet),
            _buildStatCard('Active Today', _getActiveToday(), Icons.trending_up, Colors.purple, isMobile, isTablet),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, Widget value, IconData icon, Color color, bool isMobile, bool isTablet) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 20)),
        child: isMobile ? 
          // Mobile Layout - Compact vertical
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 20),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              value,
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ) :
          // Tablet and Desktop Layout - Horizontal
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 10 : 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: isTablet ? 20 : 24),
              ),
              SizedBox(width: isTablet ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    value,
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
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

  Widget _getTotalUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _getTotalActivities() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('activities').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _getTotalTransactions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('transactions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay) // Use DateTime directly
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
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
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );
    },
  );
}
}

class _RecentUsersSection extends StatelessWidget {
  const _RecentUsersSection();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Users',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(isMobile ? 3 : 5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  child: const Center(child: CircularProgressIndicator()),
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
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = data['full_name']?.toString() ?? 'Unknown User';
                  final email = data['email']?.toString() ?? 'No email';
                  final role = data['role']?.toString() ?? 'user';
                  
                  return ListTile(
                    dense: isMobile,
                    leading: CircleAvatar(
                      radius: isMobile ? 18 : 20,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                    ),
                    title: Text(
                      fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isMobile ? 12 : 13,
                      ),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 6 : 8,
                        vertical: isMobile ? 2 : 4,
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
                          fontSize: isMobile ? 10 : 11,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// Alternative implementation for tracking login activity
class _LoginActivityChart extends StatelessWidget {
  final bool isDaily;
  
  const _LoginActivityChart({required this.isDaily});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_sessions') // You'd need to create this collection
          .where('loginTime', isGreaterThanOrEqualTo: _getTimeRange())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final loginData = _processLoginData(snapshot.data!.docs);
        
        return LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: loginData,
                isCurved: true,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Timestamp _getTimeRange() {
    final now = DateTime.now();
    if (isDaily) {
      return Timestamp.fromDate(now.subtract(const Duration(days: 7)));
    } else {
      return Timestamp.fromDate(now.subtract(const Duration(days: 30)));
    }
  }

  List<FlSpot> _processLoginData(List<QueryDocumentSnapshot> docs) {
    // Process login sessions and group by time period
    // Return FlSpot list for chart
    return [];
  }
}