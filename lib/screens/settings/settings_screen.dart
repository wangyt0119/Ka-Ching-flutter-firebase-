import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5A9C1),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Dark Mode Switch
              Card(
                child: ListTile(
                  leading: Icon(
                    themeService.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: const Color(0xFF6A0DAD),
                  ),
                  title: const Text('Dark Mode'),
                  trailing: Switch(
                    value: themeService.isDarkMode,
                    onChanged: (value) => themeService.toggleDarkMode(),
                    activeColor: const Color(0xFFF5A9C1),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Font Size Slider
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.format_size,
                            color: Color(0xFF6A0DAD),
                          ),
                          const SizedBox(width: 16),
                          const Text('Font Size'),
                        ],
                      ),
                      Slider(
                        value: themeService.fontSize,
                        min: 0.8,
                        max: 1.4,
                        divisions: 6,
                        label: '${(themeService.fontSize * 100).round()}%',
                        onChanged: (value) => themeService.setFontSize(value),
                        activeColor: const Color(0xFFF5A9C1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Aa', style: TextStyle(fontSize: 14)),
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: 14 * themeService.fontSize,
                            ),
                          ),
                          const Text('Aa', style: TextStyle(fontSize: 24)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
