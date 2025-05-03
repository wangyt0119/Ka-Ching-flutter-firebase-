import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'sign_up_screen.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      providers: [
        EmailAuthProvider(),
        GoogleProvider(clientId: "175995407076-tefkgm4be14ik8rl6h0t3v46t067shcq.apps.googleusercontent.com"),
      ],
      headerBuilder: (context, constraints, shrinkOffset) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image.asset('assets/flutterfire_300x.png'), // Your logo image
              ),
              SizedBox(height: 12),
              Text(
                'Ka-Ching', // The name of your app
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Adjust the color to fit your theme
                ),
              ),
            ],
          ),
        );
      },
      subtitleBuilder: (context, action) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Split expenses with friends easily'),
        );
      },
    );
  }
}
