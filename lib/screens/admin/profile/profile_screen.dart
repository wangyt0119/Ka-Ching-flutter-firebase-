import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth_gate.dart';
import '../../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data!;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: isMobile ?
                    // Mobile layout - vertical
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            user.email?.substring(0, 1).toUpperCase() ?? 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.email ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ) :
                    // Desktop layout - horizontal
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            user.email?.substring(0, 1).toUpperCase() ?? 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 36,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.email ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Settings Sections
              if (isMobile) ...[
                // Mobile - single column
                _buildSettingsSection('Account Settings', [
                  _buildSettingsTile(Icons.lock, 'Change Password', () {}),
                 // _buildSettingsTile(Icons.email, 'Email Preferences', () {}),
                  //_buildSettingsTile(Icons.security, 'Two-Factor Authentication', () {}),
                ]),
                // const SizedBox(height: 16),
                // _buildSettingsSection('System Settings', [
                //   _buildSettingsTile(Icons.notifications, 'Notifications', () {}),
                //   _buildSettingsTile(Icons.backup, 'Data Backup', () {}),
                //   _buildSettingsTile(Icons.update, 'System Updates', () {}),
                // ]),
                // const SizedBox(height: 16),
                // _buildSettingsSection('Support', [
                //   _buildSettingsTile(Icons.help, 'Help Center', () {}),
                //   _buildSettingsTile(Icons.bug_report, 'Report Issue', () {}),
                //   _buildSettingsTile(Icons.info, 'About', () {}),
                // ]),
              ] else ...[
                // Desktop - two columns
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildSettingsSection('Account Settings', [
                            _buildSettingsTile(Icons.lock, 'Change Password', () {}),
                            _buildSettingsTile(Icons.email, 'Email Preferences', () {}),
                            _buildSettingsTile(Icons.security, 'Two-Factor Authentication', () {}),
                          ]),
                          const SizedBox(height: 24),
                          _buildSettingsSection('System Settings', [
                            _buildSettingsTile(Icons.notifications, 'Notifications', () {}),
                            _buildSettingsTile(Icons.backup, 'Data Backup', () {}),
                            _buildSettingsTile(Icons.update, 'System Updates', () {}),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSettingsSection('Support', [
                        _buildSettingsTile(Icons.help, 'Help Center', () {}),
                        _buildSettingsTile(Icons.bug_report, 'Report Issue', () {}),
                        _buildSettingsTile(Icons.info, 'About', () {}),
                        _buildSettingsTile(Icons.logout, 'Logout', () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const AuthGate()),
                          );
                        }, isDestructive: true),
                      ]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}