import 'package:flutter/material.dart';
import 'back_button_handler.dart';

/// Simple test widget to verify back button handling
class TestBackButton extends StatelessWidget {
  const TestBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Back Button'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_back,
                size: 64,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                'Press the back button or swipe back',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'You should see an exit confirmation dialog',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


