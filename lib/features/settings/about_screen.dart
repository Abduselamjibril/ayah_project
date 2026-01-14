import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:share_plus/share_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final cardBg = theme.colorScheme.onSurface.withOpacity(0.12);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 18),
          label: Text(
            'Settings',
            style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: Text(
          'About',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 10),
          // App Logo
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Image.asset(
                  'assets/images/ayah.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App Name
          Align(
            alignment: Alignment.center,
            child: Text(
              'Quran App',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Policy links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Privacy Policy'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {},
                child: const Text('Terms of Use'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Description card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Text(
              "The app's name is derived from the saying: \u00ABConvey from me even an Ayah\u00BB.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Share/Review card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Text(
                    'Share App',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    final message = 'Check out Quran App — a beautiful Mushaf with audio, bookmarks, and daily inspiration.';
                    Share.share(message, subject: 'Quran App');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
