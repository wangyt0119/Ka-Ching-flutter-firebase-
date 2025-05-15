import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
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
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Theme Section
              const Text(
                'Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A0DAD),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (bool value) {
                  themeProvider.setDarkMode(value);
                },
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: const Color(0xFF6A0DAD),
                ),
              ),
              const Divider(),

              // Font Size Section
              const SizedBox(height: 16),
              const Text(
                'Font Size',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A0DAD),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: themeProvider.fontSize,
                    min: themeProvider.fontSizes.first,
                    max: themeProvider.fontSizes.last,
                    divisions: themeProvider.fontSizes.length - 1,
                    label: themeProvider.fontSize.toString(),
                    onChanged: (double value) {
                      themeProvider.setFontSize(value);
                    },
                    activeColor: const Color(0xFF6A0DAD),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Small'),
                        Text('${themeProvider.fontSize.toInt()}'),
                        const Text('Large'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Preview Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      themeProvider.isDarkMode
                          ? Colors.grey[800]
                          : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Preview Text',
                  style: TextStyle(
                    fontSize: themeProvider.fontSize,
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
