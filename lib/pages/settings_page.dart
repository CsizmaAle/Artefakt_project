import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artefakt_v1/theme_controller.dart';
import 'package:artefakt_v1/pages/user_manual_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) => SwitchListTile(
              title: const Text('Dark mode'),
              value: mode == ThemeMode.dark,
              onChanged: (v) => ThemeController.instance.set(v ? ThemeMode.dark : ThemeMode.light),
              secondary: const Icon(Icons.dark_mode_outlined),
            ),
          ),
          const Divider(height: 24),
          if (user != null) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Signed in as'),
              subtitle: Text(user.email ?? user.id),
            ),
            const Divider(height: 24),
          ],
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('User manual'),
            subtitle: const Text('Read how to use Artefakt'),
            onTap: () {
              final email = user?.email ?? '';
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserManualPage(email: email)),
              );
            },
          ),
          const Divider(height: 24),
          FilledButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
