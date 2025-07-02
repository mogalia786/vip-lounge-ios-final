import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GifSplashScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const GifSplashScreen({Key? key, this.onFinish}) : super(key: key);

  @override
  State<GifSplashScreen> createState() => _GifSplashScreenState();
}

class _GifSplashScreenState extends State<GifSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Optionally, you can set a timer to auto-navigate after a few seconds
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(seconds: 7), () {
        if (widget.onFinish != null) widget.onFinish!();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox.expand(
          child: Image.asset(
            'assets/splash.gif',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
