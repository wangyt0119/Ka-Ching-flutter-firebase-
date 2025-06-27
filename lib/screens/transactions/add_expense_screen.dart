import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../services/currency_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final String activityId;
  final String? activityName;
  final String? ownerId;

  // Constructor that accepts both old and new parameter formats
  const AddExpenseScreen({
    super.key, 
    required this.activityId,
    this.activityName,
    this.ownerId,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedActivityId;
  String? selectedActivityName;
  List<Map<String, dynamic>> userActivities = [];

  String selectedCurrency = 'MYR'; // default
  DateTime selectedDate = DateTime.now();
  File? _receiptImage;
  String? _base64Image;
  bool _isProcessingReceipt = false;

  String splitMethod = 'equally';
  String? paidBy = 'You';
  
  String get _currentUserLabel => 'You';
  String get _currentUserId   => _auth.currentUser!.uid;
  String get _currentUserName =>
    _auth.currentUser!.displayName ?? _auth.currentUser!.email!;

  Future<String> _toFirestoreName(String label) async {
    if (label == _currentUserLabel) {
      return _auth.currentUser!.email!;
    }
    
    // Look up the friend's email by their display name
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .where('name', isEqualTo: label)
        .limit(1)
        .get();
        
    if (friendsSnapshot.docs.isNotEmpty) {
      final friendData = friendsSnapshot.docs.first.data();
      return friendData['email'] as String? ?? label;
    }
    
    return label; // Fallback to the label if email not found
  }
  // Category selection
  String selectedCategory = 'Food';
  final List<String> categories = [
    'Food', 
    'Beverage', 
    'Entertainment', 
    'Transportation', 
    'Shopping', 
    'Travel', 
    'Utilities', 
    'Other'
  ];

  List<String> allParticipants = [];
  Map<String, bool> selectedParticipants = {};

  Map<String, double> customShares = {};
  Map<String, TextEditingController> shareControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _loadUserCurrency();
  }

  Future<void> _fetchActivities() async {
    final user = _auth.currentUser!;
    final List<Map<String, dynamic>> allActivities = [];

    // First, get activities created by the current user
    final ownActivitiesSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .get();

    final ownActivities = await Future.wait(ownActivitiesSnapshot.docs.map((doc) async {
      final activityData = doc.data();
      
      // Get the latest friends list
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();
          
      final friends = friendsSnapshot.docs.map((friendDoc) {
        return friendDoc.data()['name'] as String;
      }).toList();
      
      return {
        'id': doc.id,
        'name': activityData['name'] ?? 'Unnamed Activity',
        'friends': friends,
        'ownerId': user.uid,
        'isCreator': true,
      };
    }).toList());

    allActivities.addAll(ownActivities);

    // Then, get activities where user is a participant (but not creator)
    final usersSnapshot = await _firestore
        .collection('users')
        .get();

    for (var userDoc in usersSnapshot.docs) {
      if (userDoc.id == user.uid) continue;
      
      final activitiesSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('activities')
          .get();

      for (var activityDoc in activitiesSnapshot.docs) {
        final activityData = activityDoc.data();
        final members = activityData['members'] as List<dynamic>? ?? [];
        bool isParticipant = false;
        
        for (var member in members) {
          if (member is Map<String, dynamic> && 
              (member['id'] == user.uid || 
               member['email'] == user.email)) {
            isParticipant = true;
            break;
          }
        }
        
        if (isParticipant) {
          // Get the latest friends list for this activity
          final friendsSnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('friends')
              .get();
              
          final friends = friendsSnapshot.docs.map((friendDoc) {
            return friendDoc.data()['name'] as String;
          }).toList();
          
          allActivities.add({
            'id': activityDoc.id,
            'name': activityData['name'] ?? 'Unnamed Activity',
            'friends': friends,
            'ownerId': userDoc.id,
            'isCreator': false,
          });
        }
      }
    }

    setState(() {
      userActivities = allActivities;
      if (allActivities.isNotEmpty) {
        // If activityId was provided, select that activity
        if (widget.activityId.isNotEmpty) {
          final selectedActivity = allActivities.firstWhere(
            (activity) => activity['id'] == widget.activityId,
            orElse: () => allActivities[0],
          );
          selectedActivityId = selectedActivity['id'];
          selectedActivityName = selectedActivity['name'];
          _setParticipants(selectedActivity['friends']);
        } else {
          selectedActivityId = allActivities[0]['id'];
          selectedActivityName = allActivities[0]['name'];
          _setParticipants(allActivities[0]['friends']);
        }
      }
    });
  }

  Future<void> _loadUserCurrency() async {
    final currencyService = CurrencyService();
    final currency = await currencyService.getSelectedCurrency();
    setState(() {
      selectedCurrency = currency.code;
    });
  }

  Future<void> _updateCurrency(String newCurrency) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'currency': newCurrency,
        });

        final currencyService = CurrencyService();
        final currency =
            currencyService.getCurrencyByCode(newCurrency) ??
                currencyService.getDefaultCurrency();
        await currencyService.setSelectedCurrency(currency);

        setState(() {
          selectedCurrency = newCurrency;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Currency updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating currency: $e')),
      );
    }
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: CurrencyService.supportedCurrencies.length,
            itemBuilder: (context, index) {
              final currency =
                  CurrencyService.supportedCurrencies.keys.elementAt(index);
              final currencyInfo =
                  CurrencyService.supportedCurrencies[currency];
              return ListTile(
                title: Text(currencyInfo ?? currency),
                trailing: currency == selectedCurrency
                    ? const Icon(Icons.check, color: Color(0xFFF5A9C1))
                    : null,
                onTap: () {
                  _updateCurrency(currency);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _setParticipants(List<String> friends) {
    final members = [_currentUserLabel, ...friends];
    setState(() {
      allParticipants = members;
      selectedParticipants = {for (var name in members) name: true};
      paidBy = 'You';
      
      // Initialize share controllers for all participants
      for (var participant in members) {
        if (!shareControllers.containsKey(participant)) {
          shareControllers[participant] = TextEditingController();
        }
      }
      
      // Reset custom shares
      customShares = {};
      for (var participant in members) {
        customShares[participant] = 0.0;
        if (shareControllers.containsKey(participant)) {
          shareControllers[participant]!.text = '';
        }
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 100, // Maximum quality for OCR
    );

    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
        _isProcessingReceipt = true;
      });

      print('=== SMART OCR WORKFLOW ===');
      print('Step 1: Processing OCR on original high-quality file');
      print('Step 2: Will encode to base64 only AFTER successful OCR');

      // STEP 1: Process OCR immediately with original file (maximum quality)
      await _processReceiptWithOCR(File(pickedFile.path));
    }
  }

  // Add camera option for better receipt capture
  Future<void> _pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 100, // Maximum quality for OCR
    );

    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
        _isProcessingReceipt = true;
      });

      print('=== SMART OCR WORKFLOW (CAMERA) ===');
      print('Step 1: Processing OCR on original camera image');
      print('Step 2: Will encode to base64 only AFTER successful OCR');

      // STEP 1: Process OCR immediately with original file (maximum quality)
      await _processReceiptWithOCR(File(pickedFile.path));
    }
  }

  // Simple OCR processing using OCR.space API
  Future<void> _processReceiptWithOCR(File imageFile) async {
    try {
      print('=== SIMPLE OCR PROCESSING ===');
      print('Processing original file: ${imageFile.path}');
      print('File size: ${await imageFile.length()} bytes');

      // Convert image to base64 for OCR.space API
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      print('Calling OCR.space API...');

      // Call OCR.space API
      final response = await http.post(
        Uri.parse('https://api.ocr.space/parse/image'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'base64Image': 'data:image/jpeg;base64,$base64Image',
          'language': 'eng',
          'isOverlayRequired': 'false',
          'detectOrientation': 'true',
          'scale': 'true',
          'OCREngine': '2',
          'apikey': 'helloworld',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['ParsedResults'] != null &&
            jsonResponse['ParsedResults'].isNotEmpty) {

          final parsedText = jsonResponse['ParsedResults'][0]['ParsedText'] ?? '';

          print('=== RAW OCR TEXT ===');
          print(parsedText);
          print('=== END RAW TEXT ===');

          // Extract amount using our detection
          final detectedAmount = _extractAmountFromOCRText(parsedText);

          if (detectedAmount != null && mounted) {
            setState(() {
              _isProcessingReceipt = false;
              // Auto-fill the detected amount
              _amountController.text = detectedAmount.toStringAsFixed(2);
            });

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎯 OCR found TOTAL: \$${detectedAmount.toStringAsFixed(2)}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Details',
                  textColor: Colors.white,
                  onPressed: () {
                    _showOCRDetailsDialog(parsedText, detectedAmount);
                  },
                ),
              ),
            );

            // Save image after successful OCR
            await _handleImageStorageAfterOCR(imageFile);

          } else {
            // OCR couldn't find amount
            if (mounted) {
              setState(() {
                _isProcessingReceipt = false;
              });

              // Still save the image
              await _handleImageStorageAfterOCR(imageFile);

              // Show the detected text for manual review
              _showOCRDetailsDialog(parsedText, null);
            }
          }
        } else {
          throw Exception('No text detected in image');
        }
      } else {
        throw Exception('OCR API failed: ${response.statusCode}');
      }

    } catch (e) {
      print('OCR processing error: $e');
      if (mounted) {
        setState(() {
          _isProcessingReceipt = false;
        });

        // Still save the image even if OCR fails
        await _handleImageStorageAfterOCR(imageFile);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ OCR failed: $e'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Manual Entry',
              textColor: Colors.white,
              onPressed: () {
                // Focus on amount field for manual entry
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
          ),
        );
      }
    }
  }



  // Extract amount from OCR.space text (works with plain text)
  double? _extractAmountFromOCRText(String ocrText) {
    print('=== ANALYZING OCR TEXT FOR TOTAL/SUBTOTAL ===');

    // Split text into lines
    final allLines = ocrText.split('\n');

    // Print all detected lines
    for (int i = 0; i < allLines.length; i++) {
      print('OCR Line $i: "${allLines[i]}"');
    }

    // Look for TOTAL lines first (highest priority)
    for (String line in allLines) {
      final upperLine = line.toUpperCase();

      if (upperLine.contains('TOTAL')) {
        print('Found TOTAL line: "$line"');

        // Extract numbers from this line using multiple patterns
        final patterns = [
          RegExp(r'(\d+\.\d{2})'), // Decimal numbers like 14.55
          RegExp(r'(\d+\.\d{1})'), // Single decimal like 14.5
          RegExp(r'(\d+)'),        // Whole numbers like 14
        ];

        for (final pattern in patterns) {
          final matches = pattern.allMatches(line);
          for (final match in matches) {
            final numberStr = match.group(0)!;
            final number = double.tryParse(numberStr);

            if (number != null && number > 1 && number < 10000) {
              print('✅ EXTRACTED TOTAL: $number from "$line"');
              return number;
            }
          }
        }
      }
    }

    // Look for SUBTOTAL if no TOTAL found
    for (String line in allLines) {
      final upperLine = line.toUpperCase();

      if (upperLine.contains('SUBTOTAL')) {
        print('Found SUBTOTAL line: "$line"');

        final patterns = [
          RegExp(r'(\d+\.\d{2})'),
          RegExp(r'(\d+\.\d{1})'),
          RegExp(r'(\d+)'),
        ];

        for (final pattern in patterns) {
          final matches = pattern.allMatches(line);
          for (final match in matches) {
            final numberStr = match.group(0)!;
            final number = double.tryParse(numberStr);

            if (number != null && number > 1 && number < 10000) {
              print('✅ EXTRACTED SUBTOTAL: $number from "$line"');
              return number;
            }
          }
        }
      }
    }

    // Last resort: find largest decimal number in entire text
    List<double> allNumbers = [];
    final decimalPattern = RegExp(r'(\d+\.\d{2})');

    final matches = decimalPattern.allMatches(ocrText);
    for (final match in matches) {
      final numberStr = match.group(0)!;
      final number = double.tryParse(numberStr);
      if (number != null && number > 5 && number < 10000) {
        allNumbers.add(number);
        print('Found decimal number: $number');
      }
    }

    if (allNumbers.isNotEmpty) {
      allNumbers.sort((a, b) => b.compareTo(a)); // Sort descending
      final largest = allNumbers.first;
      print('✅ SELECTED LARGEST: $largest');
      return largest;
    }

    print('❌ NO AMOUNTS FOUND');
    return null;
  }

  // Show OCR details dialog
  void _showOCRDetailsDialog(String detectedText, double? amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OCR Results'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (amount != null) ...[
                Text(
                  'Detected Amount: \$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'No amount detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Raw OCR Text:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  detectedText.isEmpty ? 'No text detected' : detectedText,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (amount == null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Focus on amount field for manual entry
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: const Text('Manual Entry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Handle image storage AFTER OCR processing
  Future<void> _handleImageStorageAfterOCR(File imageFile) async {
    try {
      print('=== ENCODING FOR FIREBASE STORAGE ===');
      print('OCR complete, now encoding to base64 for storage...');

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      setState(() {
        _base64Image = base64Image;
      });

      print('Image encoded for Firebase storage (${base64Image.length} characters)');
      print('✅ OCR was done on original file, storage is separate');

    } catch (e) {
      print('Error encoding image for storage: $e');
    }
  }

  String _getParticipantIdentifier(String displayName) {
    if (displayName == 'You' || displayName == _currentUserLabel) {
      return _auth.currentUser!.email!;
    }
    
    // For friends, you might need to store their emails when creating activities
    // For now, we'll return the display name, but ideally you should store friend emails
    return displayName;
  }
  Future<void> _submitExpense() async {
  if (!_formKey.currentState!.validate() || selectedActivityId == null)
    return;

  // Validate split amounts match total for unequal and percentage splits
  if (splitMethod == 'unequally') {
    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final totalShares = customShares.values.fold(0.0, (sum, amount) => sum + amount);
    
    if ((totalAmount - totalShares).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Total shares ($totalShares) must equal the expense amount ($totalAmount)')),
      );
      return;
    }
  } else if (splitMethod == 'percentage') {
    final totalPercentage = customShares.values.fold(0.0, (sum, amount) => sum + amount);
    
    if ((totalPercentage - 100.0).abs() > 0.1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Total percentage must equal 100% (currently $totalPercentage%)')),
      );
      return;
    }
  }

  final user = _auth.currentUser!;
  final selectedActivity = userActivities.firstWhere((a) => a['id'] == selectedActivityId);
  final ownerId = selectedActivity['ownerId'] ?? user.uid;
  
  // Always use email identifiers for consistency
  String payerIdentifier = paidBy == _currentUserLabel 
      ? user.email! 
      : await _toFirestoreName(paidBy!);
  
  // Get participants as email identifiers
  List<String> participantIdentifiers = [];
  for (var entry in selectedParticipants.entries) {
    if (entry.value) { // Only include selected participants
      String email = entry.key == _currentUserLabel 
          ? user.email! 
          : await _toFirestoreName(entry.key);
      participantIdentifiers.add(email);
    }
  }
  
  // Create expense document
  final expense = {
    'title': _titleController.text,
    'amount': double.parse(_amountController.text),
    'currency': selectedCurrency,
    'date': selectedDate.toIso8601String(),
    'timestamp': FieldValue.serverTimestamp(),
    'description': _descriptionController.text,
    'category': selectedCategory,
    'paid_by': payerIdentifier,
    'paid_by_id': payerIdentifier == user.email ? user.uid : '',
    'participants': participantIdentifiers,
    'split': splitMethod,
    'receipt_image': _base64Image,
  };

  // Handle different split methods - use emails/identifiers as keys
  if (splitMethod == 'unequally' || splitMethod == 'percentage') {
    final shares = <String, double>{};
    
    for (var participant in selectedParticipants.entries.where((e) => e.value).map((e) => e.key)) {
      String participantEmail = participant == _currentUserLabel 
          ? user.email! 
          : await _toFirestoreName(participant);
      shares[participantEmail] = customShares[participant] ?? 0.0;
    }
    
    expense['shares'] = shares;
  }

  await _firestore
      .collection('users')
      .doc(ownerId)
      .collection('activities')
      .doc(selectedActivityId)
      .collection('transactions')
      .add(expense);

  await _recalculateBalances(ownerId: ownerId, activityId: selectedActivityId!);

  if (!mounted) return;

  Navigator.pop(context, true);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Expense added and balances updated')),
  );
}

  Future<void> _recalculateBalances({
  required String ownerId,
  required String activityId,
}) async {
  final activityRef = _firestore
      .collection('users')
      .doc(ownerId)
      .collection('activities')
      .doc(activityId);

  // Get current activity data
  final activityDoc = await activityRef.get();
  final activityData = activityDoc.data() ?? {};
  
  // Get or initialize the currency-specific balances
  Map<String, Map<String, double>> balancesByCurrency = {};
  
  if (activityData.containsKey('balances_by_currency')) {
    final rawBalancesByCurrency = activityData['balances_by_currency'] as Map<String, dynamic>?;
    if (rawBalancesByCurrency != null) {
      rawBalancesByCurrency.forEach((currency, balanceData) {
        balancesByCurrency[currency] = Map<String, double>.from(balanceData);
      });
    }
  }

  final txnSnap = await activityRef.collection('transactions').get();

  // Reset all balances to 0
  balancesByCurrency.clear();

  // -------- scan every transaction --------
  for (final doc in txnSnap.docs) {
    final t = doc.data();
    final double amount = (t['amount'] as num).toDouble();
    final String currency = t['currency'] ?? 'MYR'; // Default to MYR if not specified
    final String payer = t['paid_by'] as String; // This should already be an email
    final List participants = List.from(t['participants'] ?? []);

    // Initialize currency in balancesByCurrency if not exists
    if (!balancesByCurrency.containsKey(currency)) {
      balancesByCurrency[currency] = {};
    }

    // Handle settlement transactions
    if (t['is_settlement'] == true) {
      final settlementFrom = t['settlement_from'] ?? '';
      final settlementTo = t['settlement_to'] ?? '';
      
      if (settlementFrom.isNotEmpty && settlementTo.isNotEmpty) {
        // Adjust balances for settlement in the specific currency
        balancesByCurrency[currency]![settlementFrom] = 
            (balancesByCurrency[currency]![settlementFrom] ?? 0.0) + amount;
        balancesByCurrency[currency]![settlementTo] = 
            (balancesByCurrency[currency]![settlementTo] ?? 0.0) - amount;
      }
      continue;
    }

    // ---- work out each participant's share ----
    Map<String, double> shares = {};
    final split = t['split'] ?? 'equally';

    if (split == 'equally') {
      final each = amount / participants.length;
      for (final p in participants) {
        // Ensure p is an email identifier
        final String participantEmail = p as String;
        shares[participantEmail] = each;
      }
    } else if (split == 'unequally' || split == 'percentage') {
      shares = Map<String, double>.from(t['shares'] ?? {});
      
      // For percentage split, convert percentages to actual amounts
      if (split == 'percentage') {
        shares.forEach((person, percentage) {
          shares[person] = amount * percentage / 100.0;
        });
      }
    }

    // ---- update balances ----
    // Add the full amount to the payer's balance in the specific currency
    balancesByCurrency[currency]![payer] = 
        (balancesByCurrency[currency]![payer] ?? 0.0) + amount;
    
    // Subtract each participant's share in the specific currency
    shares.forEach((person, share) {
      balancesByCurrency[currency]![person] = 
          (balancesByCurrency[currency]![person] ?? 0.0) - share;
    });
  }

  // -------- clean up small values --------
  balancesByCurrency.forEach((currency, currencyBalances) {
    currencyBalances.removeWhere((key, value) => value.abs() < 0.01);
  });

  // -------- write back on the activity doc --------
  await activityRef.update({
    'balances_by_currency': balancesByCurrency,
  });
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Select Activity",
                  prefixIcon: const Icon(Icons.event, color: Color(0xFFB19CD9)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                ),
                value: selectedActivityId,
                items: userActivities.map((activity) {
                  return DropdownMenuItem<String>(
                    value: activity['id'],
                    child: Text(activity['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  final selected = userActivities.firstWhere(
                    (act) => act['id'] == value,
                  );
                  setState(() {
                    selectedActivityId = value;
                    selectedActivityName = selected['name'];
                    _setParticipants(List<String>.from(selected['friends']!));
                  });
                },
              ),
              const SizedBox(height: 16),
              // Currency
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFB19CD9)),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                ),
                
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Currency: $selectedCurrency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB19CD9)),
                    ),
                    TextButton(
                      onPressed: _showCurrencyDialog,
                      child: const Text(
                        'Change',
                        style: TextStyle(color: Color(0xFFF5A9C1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  prefixIcon: const Icon(Icons.title, color: Color(0xFFB19CD9)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFB19CD9),
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) => val!.isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: Color(0xFFB19CD9),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFB19CD9),
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) => val!.isEmpty ? "Enter an amount" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Date",
                  prefixIcon: const Icon(
                    Icons.date_range,
                    color: Color(0xFFB19CD9),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFB19CD9),
                      width: 2,
                    ),
                  ),
                ),
                controller: TextEditingController(
                  text: DateFormat.yMd().format(selectedDate),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Description (optional)",
                  prefixIcon: const Icon(
                    Icons.description,
                    color: Color(0xFFB19CD9),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFB19CD9),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Category",
                  prefixIcon: const Icon(Icons.category, color: Color(0xFFB19CD9)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB19CD9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFB19CD9),
                      width: 2,
                    ),
                  ),
                ),
                value: selectedCategory,
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Color(0xFFB19CD9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isProcessingReceipt)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB19CD9)),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                "🔍 Processing receipt with OCR...\nExtracting TOTAL amount from image",
                                style: TextStyle(color: Color(0xFFB19CD9)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFFB19CD9),
                            ),
                            title: const Text("Take Photo of Receipt"),
                            subtitle: const Text("📸 Camera → OCR → Auto-fill amount"),
                            onTap: _pickImageFromCamera,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.photo_library,
                              color: Color(0xFFB19CD9),
                            ),
                            title: const Text("Choose from Gallery"),
                            subtitle: const Text("🖼️ Gallery → OCR → Auto-fill amount"),
                            onTap: _pickImage,
                          ),
                        ],
                      ),
                    if (_base64Image != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Receipt Image:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_base64Image!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                "Paid By",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Column(
                children:
                    allParticipants
                        .map(
                          (name) => RadioListTile<String>(
                            title: Text(name),
                            value: name,
                            groupValue: paidBy,
                            activeColor: Color(0xFFB19CD9),
                            onChanged:
                                (value) => setState(() => paidBy = value),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                "Split",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Equally"),
                    selected: splitMethod == 'equally',
                    selectedColor: Color(0xFFF5A9C1),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          splitMethod == 'equally'
                              ? Colors.white
                              : Color(0xFFB19CD9),
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: Color(0xFFB19CD9)),
                    onSelected: (_) => setState(() => splitMethod = 'equally'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Unequally"),
                    selected: splitMethod == 'unequally',
                    selectedColor: Color(0xFFF5A9C1),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          splitMethod == 'unequally'
                              ? Colors.white
                              : Color(0xFFB19CD9),
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: Color(0xFFB19CD9)),
                    onSelected:
                        (_) => setState(() => splitMethod = 'unequally'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("By %"),
                    selected: splitMethod == 'percentage',
                    selectedColor: Color(0xFFF5A9C1),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color:
                          splitMethod == 'percentage'
                              ? Colors.white
                              : Color(0xFFB19CD9),
                      fontWeight: FontWeight.bold,
                    ),
                    side: const BorderSide(color: Color(0xFFB19CD9)),
                    onSelected:
                        (_) => setState(() => splitMethod = 'percentage'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Add the split method UI
              _buildSplitMethodUI(),
              const SizedBox(height: 24),
              const Text(
                "Participants",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...allParticipants.map(
                (name) => CheckboxListTile(
                  title: Text(name),
                  value: selectedParticipants[name] ?? false,
                  activeColor: Color(0xFFB19CD9),
                  onChanged:
                      (value) =>
                          setState(() => selectedParticipants[name] = value!),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitExpense,
                  child: const Text(
                    "ADD EXPENSE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitMethodUI() {
    final activeParticipants = selectedParticipants.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
        
    if (activeParticipants.isEmpty) {
      return const Text('Please select participants first');
    }
    
    if (splitMethod == 'equally') {
      // For equally split, just show the participants
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Each person pays:'),
          const SizedBox(height: 8),
          ...activeParticipants.map((name) {
            double amount = 0.0;
            try {
              amount = _amountController.text.isEmpty 
                  ? 0.0 
                  : (double.parse(_amountController.text) / activeParticipants.length);
            } catch (e) {
              // Handle parsing error
              print('Error parsing amount: $e');
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name),
                  Text('$selectedCurrency ${amount.toStringAsFixed(2)}'),
                ],
              ),
            );
          }).toList(),
        ],
      );
    } else if (splitMethod == 'unequally') {
      // For unequal split, show text fields for each participant
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Enter amount for each person:'),
          const SizedBox(height: 8),
          ...activeParticipants.map((name) {
            // Make sure controller exists
            if (!shareControllers.containsKey(name)) {
              shareControllers[name] = TextEditingController();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(name),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: shareControllers[name],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: '$selectedCurrency ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          customShares[name] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '$selectedCurrency ${customShares.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_amountController.text.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expense amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$selectedCurrency ${double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          if (_amountController.text.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Difference:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$selectedCurrency ${((double.tryParse(_amountController.text) ?? 0.0) - customShares.values.fold(0.0, (sum, amount) => sum + amount)).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ((double.tryParse(_amountController.text) ?? 0.0) - customShares.values.fold(0.0, (sum, amount) => sum + amount)).abs() < 0.01
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
        ],
      );
    } else if (splitMethod == 'percentage') {
      // For percentage split, show percentage fields for each participant
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Enter percentage for each person:'),
          const SizedBox(height: 8),
          ...activeParticipants.map((name) {
            // Make sure controller exists
            if (!shareControllers.containsKey(name)) {
              shareControllers[name] = TextEditingController();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(name),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: shareControllers[name],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          customShares[name] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total percentage:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${customShares.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (customShares.values.fold(0.0, (sum, amount) => sum + amount) - 100.0).abs() < 0.1
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
          if (_amountController.text.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('Amount breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...activeParticipants.map((name) {
                  final percentage = customShares[name] ?? 0.0;
                  double amount = 0.0;
                  try {
                    amount = _amountController.text.isEmpty
                        ? 0.0
                        : (double.parse(_amountController.text) * percentage / 100);
                  } catch (e) {
                    // Handle parsing error
                    print('Error parsing amount: $e');
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name),
                        Text('$selectedCurrency ${amount.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
        ],
      );
    }
    return const SizedBox();
  }
}