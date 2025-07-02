import 'package:flutter/material.dart';

class WelcomeSplashScreen extends StatelessWidget {
  final VoidCallback? onFinish;
  const WelcomeSplashScreen({Key? key, this.onFinish}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      if (onFinish != null) onFinish!();
    });
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Welcome',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 48,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
