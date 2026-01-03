import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'search_page2.dart' as search2;
import 'new_post_page.dart';
import 'settings_page.dart';
import 'feed_page.dart';
import 'messages_page.dart';

class HomePage extends StatefulWidget {
  final String email;
  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

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
