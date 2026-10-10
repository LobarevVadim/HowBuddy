import 'package:flutter/material.dart';

import 'app_style.dart';
import 'features/auth/auth_pages.dart';

void main() {
  runApp(const HowBuddyApp());
}

class HowBuddyApp extends StatelessWidget {
  const HowBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HowBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const LoadingPage(),
    );
  }
}

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.loadingBackground,
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('assets/images/howbuddy_loading.jpg'),
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}
