import 'package:flutter/material.dart';

class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Không có quyền')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56),
                SizedBox(height: 16),
                Text(
                  'Bạn không có quyền sử dụng chức năng này.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
