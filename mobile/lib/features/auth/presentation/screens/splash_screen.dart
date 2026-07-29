import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apartment_rounded, size: 56),
              SizedBox(height: 16),
              Text(
                'TTsmart',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Đang kiểm tra phiên đăng nhập...'),
            ],
          ),
        ),
      ),
    );
  }
}
