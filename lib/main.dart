// lib/main.dart
import 'package:flutter/material.dart';
// import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/auth_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'App',
        themeMode: mode,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF6750A4),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF6750A4),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          brightness: Brightness.dark,
        ),
        routes: {
          '/login': (_) => const AuthPage(),
        },
        home: _SupabaseGate(),
      ),
    );
  }
}
class _SupabaseGate extends StatefulWidget {
  @override
  State<_SupabaseGate> createState() => _SupabaseGateState();
}

class _SupabaseGateState extends State<_SupabaseGate> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthPage();
    return HomePage(email: session.user.email ?? '');
  }
}
