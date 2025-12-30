import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/pages/user_manual_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _loginKey = GlobalKey<FormState>();
  final _regKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _regUsername = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  bool _loginObscure = true;
  bool _regObscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = Supabase.instance.client.auth.currentSession?.user.email;
      if (!mounted || email == null) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => UserManualPage(email: email)),
      );
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _regUsername.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
    return null;
  }

  String? _passValidator(String? v) => (v == null || v.length < 6) ? 'Min 6 chars' : null;
  String? _usernameValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Pick a username';
    final value = v.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(value)) return '3-20: letters, digits, . or _';
    return null;
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _doLogin() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _loginEmail.text.trim(),
        password: _loginPass.text,
      );
      final email = res.user?.email;
      if (!mounted) return;
      if (email != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => UserManualPage(email: email)),
        );
      } else {
        _showSnack('Invalid credentials');
      }
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doRegister() async {
    if (!_regKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      final email = _regEmail.text.trim();
      final password = _regPass.text;
      final username = _regUsername.text.trim().toLowerCase();
      final res = await auth.signUp(email: email, password: password);
      final uid = res.user?.id;
      if (uid == null) {
        throw const AuthException('signup_failed');
      }
      try {
        await Supabase.instance.client.from('profiles').insert({
          'id': uid,
          'email': email,
          'username': username,
        });
      } on PostgrestException catch (pe) {
        if (pe.code == '23505') {
          _showSnack('Username already taken.');
          return;
        }
        rethrow;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => UserManualPage(email: email)),
      );
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Sign in', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TabBar(controller: _tab, tabs: const [Tab(text: 'Login'), Tab(text: 'Create account')]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        SingleChildScrollView(
                          child: Form(
                            key: _loginKey,
                            child: Column(children: [
                              TextFormField(controller: _loginEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: _emailValidator),
                              const SizedBox(height: 12),
                              TextFormField(controller: _loginPass, obscureText: _loginObscure, decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(icon: Icon(_loginObscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _loginObscure = !_loginObscure))), validator: _passValidator),
                              const SizedBox(height: 20),
                              SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _doLogin, child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'))),
                            ]),
                          ),
                        ),
                        SingleChildScrollView(
                          child: Form(
                            key: _regKey,
                            child: Column(children: [
                              TextFormField(controller: _regUsername, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username (unique)'), validator: _usernameValidator),
                              const SizedBox(height: 12),
                              TextFormField(controller: _regEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: _emailValidator),
                              const SizedBox(height: 12),
                              TextFormField(controller: _regPass, obscureText: _regObscure, decoration: InputDecoration(labelText: 'Password (min. 6)', suffixIcon: IconButton(icon: Icon(_regObscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _regObscure = !_regObscure))), validator: _passValidator),
                              const SizedBox(height: 20),
                              SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _doRegister, child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create account'))),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
