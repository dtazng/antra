// Legacy screen replaced by AuthScreen + AuthGate (016-ui-auth-settings).
// Retained as a redirect to avoid breaking any lingering imports.
import 'package:flutter/material.dart';
import 'package:antra/screens/auth/auth_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => const AuthScreen();
}
