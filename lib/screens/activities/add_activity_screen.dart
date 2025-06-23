import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../theme/app_theme.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  // Current-user data
  String _userEmail = '';
  String _userName  = '';

  // Friends list and selection
  List<Map<String, dynamic>> _friends           = [];
  final List<Map<String, dynamic>> _selected    = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────
  //   HELPERS
  // ───────────────────────────────────────────────────────────────
  Map<String, double> _initialBalances() {
    // Build { email : 0.0 } including the creator
    final Map<String, double> map = {};
    for (final m in _selected.where((e) => e['selected'] == true)) {
      map[m['email']] = 0.0;
    }
    return map;
  }

  // ───────────────────────────────────────────────────────────────
  //   FIRESTORE
  // ───────────────────────────────────────────────────────────────
  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc  = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data     = userDoc.data();

    setState(() {
      _userEmail = user.email ?? '';
      _userName  = data?['full_name'] ?? 'You';
      // Pre-select yourself
      _selected.add({
        'id'      : user.uid,
        'name'    : _userName,
        'email'   : _userEmail,
        'selected': true,
      });
    });
  }

  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();

      setState(() {
        _friends = snap.docs
            .map((d) => {
                  'id'      : d.id,
                  'name'    : d['name']  ?? '',
                  'email'   : d['email'] ?? '',
                  'selected': false,
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  Future<void> _createActivity() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity name')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ── references & providers
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .doc(); // auto-ID

      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final currency = currencyProvider.selectedCurrency.code;

      // ── members (= selected checkboxes)
      final members = _selected
          .where((m) => m['selected'] == true)
          .map((m) => {
                'id'   : m['id'],
                'name' : m['name'],
                'email': m['email'],
              })
          .toList();

      // ── Firestore write
      await ref.set({
        'activity_id'  : ref.id,
        'name'         : _nameCtrl.text.trim(),
        'description'  : _descCtrl.text.trim(),
        'members'      : members,
        'createdAt'    : FieldValue.serverTimestamp(),
        'createdBy'    : user.uid,
        'createdByName': _userName,
        'currency'     : currency,
        'totalAmount'  : 0.0,                 // NEW -> keeps charts happy
        'balances'     : _initialBalances(),  // NEW -> Summary card works
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity created successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error creating activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ───────────────────────────────────────────────────────────────
  //   UI
  // ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Create Activity',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── NAME ──────────────────────────────────────────────
            TextField(
              controller: _nameCtrl,
              decoration: _fieldDecoration(
                label: 'Activity Name',
                icon : Icons.celebration,
              ),
            ),
            const SizedBox(height: 16),

            // ── DESCRIPTION ───────────────────────────────────────
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: _fieldDecoration(
                label: 'Description (optional)',
                icon : Icons.description,
              ),
            ),
            const SizedBox(height: 24),

            // ── PARTICIPANTS ───────────────────────────────────────
            const Text('Participants',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Select friends to include in this activity',
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),

            // Current user (always included)
            ListTile(
              leading: _avatar(_userName),
              title : const Text('You'),
              subtitle: Text(_userEmail),
              trailing: const Icon(Icons.check_circle, color: Colors.pink),
            ),
            const Divider(height: 32),

            // Friends
            const Text('Friends',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _friends.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text("You haven't added any friends yet",
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _friends.length,
                    itemBuilder: (_, i) {
                      final f = _friends[i];
                      return ListTile(
                        leading : _avatar(f['name']),
                        title   : Text(f['name']),
                        subtitle: Text(f['email']),
                        trailing : Checkbox(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          activeColor: const Color(0xFFB19CD9),
                          value: f['selected'],
                          onChanged: (v) => setState(() {
                            _friends[i]['selected'] = v;
                            if (v == true) {
                              _selected.add(_friends[i]);
                            } else {
                              _selected.removeWhere(
                                  (m) => m['id'] == f['id']);
                            }
                          }),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _createActivity,
            child: const Text('CREATE ACTIVITY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  //   SMALL WIDGET HELPERS
  // ───────────────────────────────────────────────────────────────
  InputDecoration _fieldDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFB19CD9)),
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB19CD9))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB19CD9))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFB19CD9), width: 2)),
    );
  }

  CircleAvatar _avatar(String name) => CircleAvatar(
        backgroundColor: AppTheme.primaryColor,
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white)),
      );
}
