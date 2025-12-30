import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'search_page2.dart' as search2;
import 'new_post_page.dart';
import 'settings_page.dart';
import 'feed_page.dart';
import 'messages_page.dart';
// Dacă NU folosești rute numite pentru login, poți importa direct AuthPage și
// folosi pushAndRemoveUntil în _onLogoutPressed (vezi comentariul din funcție).
// import 'auth_page.dart';

class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  // Paginile între care navigăm (placeholder — le poți înlocui cu pagini reale)
  List<Widget> get _pages => const [
        Center(child: Text("Home")),
        Center(child: Text("Messages")),
        Center(child: Text("New post")),
        Center(child: Text("Profilul tău")),
      ];

  Future<void> _onLogoutPressed() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delogare'),
            content: const Text('Ești sigură că vrei să te deloghezi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nu'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Da'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // VARIANTA 1 – cu rută numită (ai nevoie de '/login' în MaterialApp.routes)
    await Supabase.instance.client.auth.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);

    // VARIANTA 2 – fără rute numite (de-comentează dacă preferi asta)
    // Navigator.of(context).pushAndRemoveUntil(
    //   MaterialPageRoute(builder: (_) => const AuthPage()),
    //   (route) => false,
    // );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FeedPage(),
      const search2.SearchPage(),
      const MessagesPage(),
      NewPostPage(
        onPosted: () {
          setState(() {
            _index = 4; // Switch to Profile tab after posting
          });
        },
      ),
      const ProfilePage(),
    ];
    final safeIndex = _index.clamp(0, pages.length - 1);
    const titles = ['Home', 'Search', 'Messages', 'New Post', 'Profile'];
    final currentTitle = titles[safeIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTitle),
        centerTitle: true,
        actions: safeIndex == 4
            ? [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: pages[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (int newIndex) {
          setState(() {
            _index = newIndex;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.post_add_rounded), label: 'New Post'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}






