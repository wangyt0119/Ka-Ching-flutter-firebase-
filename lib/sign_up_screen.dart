import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart'; 
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      providers: [
        EmailAuthProvider(),
        GoogleProvider(clientId: "175995407076-tefkgm4be14ik8rl6h0t3v46t067shcq.apps.googleusercontent.com"),
      ],
      headerBuilder: (context, constraints, shrinkOffset) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image(image: AssetImage('flutterfire_300x.png')),
          ),
        );
      },
      subtitleBuilder: (context, action) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Welcome to FlutterFire, please sign up!'),
        );
      },
      footerBuilder: (context, action) {
        return const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'By signing up, you agree to our terms and conditions.',
            style: TextStyle(color: Colors.grey),
          ),
        );
      },
    );
  }
}

