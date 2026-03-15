import 'package:flutter/material.dart';

import 'package:antra/widgets/aurora_background.dart';

/// Shown briefly during the async session check on cold launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        variant: AuroraVariant.dayView,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
