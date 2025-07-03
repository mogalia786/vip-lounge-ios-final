import 'package:flutter/material.dart';

class ConciergeHomeScreen extends StatelessWidget {
  const ConciergeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.asset(
                'assets/Premium.ico',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.star, color: Colors.amber, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Concierge Home'),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Concierge Home Screen'),
      ),
    );
  }
}
