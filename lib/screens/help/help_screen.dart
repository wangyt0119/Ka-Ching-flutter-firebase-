import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@kaching.com',
      queryParameters: {'subject': 'KaChing App Support'},
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Could not launch $emailLaunchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5A9C1),
        elevation: 0,
        title: const Text(
          'Help & Support',
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
        padding: const EdgeInsets.all(16),
        children: [
          // FAQ Section
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A0DAD),
            ),
          ),
          const SizedBox(height: 16),
          _buildFAQItem(
            'How do I add a new transaction?',
            'Tap the + button on the home screen and fill in the transaction details.',
          ),
          _buildFAQItem(
            'How do I change my currency?',
            'Go to Profile and tap on the Currency option to select your preferred currency.',
          ),
          _buildFAQItem(
            'Can I export my transactions?',
            'Yes, go to the Reports section and use the export feature to download your transactions.',
          ),

          const SizedBox(height: 32),

          // Contact Support Section
          const Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A0DAD),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email, color: Color(0xFF6A0DAD)),
              title: const Text('Email Support'),
              subtitle: const Text('support@kaching.com'),
              onTap: _launchEmail,
            ),
          ),

          const SizedBox(height: 32),

          // App Info
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About KaChing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A0DAD),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Version: 1.0.0', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'KaChing is your personal finance companion, helping you track expenses and manage your money effectively.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            color: Color(0xFF6A0DAD),
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(answer)),
        ],
      ),
    );
  }
}
