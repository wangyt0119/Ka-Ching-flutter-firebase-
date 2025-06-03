import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'user';  // Default role is 'user'

  // Function to handle registration
  void register() async {
    try {
      // Create user with email and password
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: emailController.text,
              password: passwordController.text);

      String uid = userCred.user!.uid;

      // Save the role ('admin' or 'user') in Firebase Realtime Database
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': emailController.text,
        'role': selectedRole,
        'currency': 'MYR',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Navigate to home page after successful registration
      // You can navigate to a different screen here after registration
      print("User registered with role: $selectedRole");
    } catch (e) {
      print("Error during registration: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            // Dropdown to select role
            DropdownButton<String>(
              value: selectedRole,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (val) {
                setState(() {
                  selectedRole = val!;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: const Text("Register")),
          ],
        ),
      ),
    );
  }
}