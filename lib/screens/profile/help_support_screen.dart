import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@kaching.com',
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
        padding: const EdgeInsets.all(16.0),
        children: [
          // Contact Support Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A0DAD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.email, color: Color(0xFF6A0DAD)),
                    title: const Text('Email Support'),
                    subtitle: const Text('support@kaching.com'),
                    onTap: _launchEmail,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // FAQs Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A0DAD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFAQItem(
                    'How do I add a new transaction?',
                    'Tap the + button on the home screen and fill in the transaction details.',
                  ),
                  const Divider(),
                  _buildFAQItem(
                    'How do I edit my profile?',
                    'Go to Profile and tap the edit icon in the top right corner.',
                  ),
                  const Divider(),
                  _buildFAQItem(
                    'How do I change the currency?',
                    'Go to Profile > Settings and select your preferred currency.',
                  ),
                  const Divider(),
                  _buildFAQItem(
                    'How do I export my data?',
                    'Go to Settings > Data Management and tap "Export Data".',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // App Info Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'App Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A0DAD),
                    ),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.info, color: Color(0xFF6A0DAD)),
                    title: Text('Version'),
                    subtitle: Text('1.0.0'),
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
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(answer, style: const TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }
}
