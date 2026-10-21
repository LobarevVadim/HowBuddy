import 'package:flutter/material.dart';

import 'features/admin/admin_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HowBuddySupportAdmin());
}

class HowBuddySupportAdmin extends StatelessWidget {
  const HowBuddySupportAdmin({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HowBuddy Support',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7056D8)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: const AdminPage(),
  );
}
