import 'package:flutter/material.dart';
import 'package:artefakt_v1/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManualPage extends StatefulWidget {
  final String email;
  const UserManualPage({super.key, required this.email});

  @override
  State<UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends State<UserManualPage> {
  String _lang = 'en';

  String _resolveEmail() {
    if (widget.email.trim().isNotEmpty) return widget.email.trim();
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  void _toggleLang() {
    setState(() {
      _lang = _lang == 'en' ? 'ro' : 'en';
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolvedEmail = _resolveEmail();
    final content = _lang == 'ro' ? _roContent : _enContent;
    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
        actions: [
          TextButton(
            onPressed: _toggleLang,
            child: Text(_lang == 'en' ? 'RO' : 'EN'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              content.heading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(content.intro),
            const SizedBox(height: 16),
            ...content.sections.map((s) => _Section(title: s.title, bullets: s.bullets)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HomePage(email: resolvedEmail),
                  ),
                );
              },
              child: Text(content.cta),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _Section({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(b)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ManualContent {
  final String title;
  final String heading;
  final String intro;
  final List<_ManualSection> sections;
  final String cta;

  const _ManualContent({
    required this.title,
    required this.heading,
    required this.intro,
    required this.sections,
    required this.cta,
  });
}

class _ManualSection {
  final String title;
  final List<String> bullets;

  const _ManualSection({required this.title, required this.bullets});
}

const _ManualContent _enContent = _ManualContent(
  title: 'User Manual',
  heading: 'Welcome to Artefakt',
  intro: 'Here is a fun, quick guide to get you started.',
  cta: 'Continue to app',
  sections: [
    _ManualSection(
      title: 'About the app',
      bullets: [
        'Artefakt is a uni project made with love, late nights, and too much coffee.',
        'The goal: explore art, share inspiration, and connect with others.',
      ],
    ),
    _ManualSection(
      title: 'Home & Feed',
      bullets: [
        'Scroll the feed to discover posts.',
        'Tap a post to open details, comments, and actions.',
        'Use the heart to like and the comment icon to reply.',
      ],
    ),
    _ManualSection(
      title: 'Search',
      bullets: [
        'Search users or posts using the search bar.',
        'Use the Culturalize button to explore artists or topics.',
        'Choose EN/RO, then tap Search to read a summary.',
        'Tap images to zoom and explore details.',
      ],
    ),
    _ManualSection(
      title: 'Messages',
      bullets: [
        'Open a conversation to chat in real time.',
        'Share a post from the share button in any post.',
        'Tap a shared post card to open the full post.',
        'Keep it friendly and creative.',
      ],
    ),
    _ManualSection(
      title: 'Create a Post',
      bullets: [
        'Go to New Post, add text and optional image.',
        'Tap Post to publish.',
        'Short, thoughtful captions go a long way.',
      ],
    ),
    _ManualSection(
      title: 'Profile & Settings',
      bullets: [
        'Visit your profile to see your posts.',
        'Use Settings to manage your account.',
      ],
    ),
    _ManualSection(
      title: 'Pro tips',
      bullets: [
        'Try searching an art movement (Impressionism, Surrealism).',
        'Use Culturalize in RO for local context.',
        'Share posts to spark conversations.',
      ],
    ),
  ],
);

const _ManualContent _roContent = _ManualContent(
  title: 'Ghid de utilizare',
  heading: 'Bine ai venit la Artefakt',
  intro: 'Mai jos gasesti un ghid scurt si fun pentru inceput.',
  cta: 'Continua in aplicatie',
  sections: [
    _ManualSection(
      title: 'Despre aplicatie',
      bullets: [
        'Artefakt este un proiect de facultate facut cu mult entuziasm.',
        'Scopul: exploram arta, impartasim inspiratie si ne conectam.',
      ],
    ),
    _ManualSection(
      title: 'Acasa si Feed',
      bullets: [
        'Deruleaza feed-ul ca sa descoperi postari.',
        'Apasa pe o postare pentru detalii, comentarii si actiuni.',
        'Foloseste inima pentru like si iconita de comentariu pentru raspuns.',
      ],
    ),
    _ManualSection(
      title: 'Cautare',
      bullets: [
        'Cauta utilizatori sau postari din bara de cautare.',
        'Foloseste Culturalize pentru artisti sau subiecte.',
        'Alege EN/RO si apasa Search pentru rezumat.',
        'Apasa pe imagini pentru zoom.',
      ],
    ),
    _ManualSection(
      title: 'Mesaje',
      bullets: [
        'Deschide o conversatie pentru chat in timp real.',
        'Partajeaza o postare din butonul de share.',
        'Apasa cardul postarii pentru a deschide postarea completa.',
        'Pastreaza vibe-ul creativ.',
      ],
    ),
    _ManualSection(
      title: 'Creeaza o postare',
      bullets: [
        'Mergi la New Post, adauga text si optional imagine.',
        'Apasa Post pentru publicare.',
        'Textele scurte si sincere prind cel mai bine.',
      ],
    ),
    _ManualSection(
      title: 'Profil si Setari',
      bullets: [
        'Viziteaza profilul tau pentru postarile tale.',
        'Foloseste Settings pentru cont.',
      ],
    ),
    _ManualSection(
      title: 'Sfaturi rapide',
      bullets: [
        'Cauta miscari artistice (Impresionism, Suprarealism).',
        'Foloseste Culturalize in RO pentru context local.',
        'Trimite postari ca sa pornesti conversatii.',
      ],
    ),
  ],
);
