import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_app/core/ui/responsive.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final cardBg = theme.colorScheme.onSurface.withOpacity(0.12);
    final leadingWidth =
        ResponsiveLayout.scaled(context, 120, min: 96, max: 140);
    final backIconSize = ResponsiveLayout.scaled(context, 18, min: 16, max: 22);
    final backFontSize = ResponsiveLayout.scaled(context, 15, min: 13, max: 17);
    final titleFontSize =
        ResponsiveLayout.scaled(context, 18, min: 16, max: 20);
    final listHPad = ResponsiveLayout.scaled(context, 20, min: 14, max: 26);
    final logoSize = ResponsiveLayout.scaled(context, 108, min: 90, max: 132);
    final logoRadius = ResponsiveLayout.scaled(context, 24, min: 18, max: 30);
    final logoPadding = ResponsiveLayout.scaled(context, 20, min: 14, max: 24);
    final appNameSize = ResponsiveLayout.scaled(context, 32, min: 26, max: 36);
    final versionSize = ResponsiveLayout.scaled(context, 14, min: 12, max: 16);
    final sectionGap = ResponsiveLayout.scaled(context, 18, min: 14, max: 24);
    final titleGap = ResponsiveLayout.scaled(context, 6, min: 4, max: 10);
    final headerGap = ResponsiveLayout.scaled(context, 16, min: 12, max: 22);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: leadingWidth,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: accent, size: backIconSize),
          label: Text(
            'Settings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: accent,
              fontSize: backFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
              padding: EdgeInsets.only(
                  left: ResponsiveLayout.scaled(context, 8, min: 6, max: 12))),
        ),
        title: Text(
          'About',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: titleFontSize),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: listHPad),
        children: [
          SizedBox(
              height: ResponsiveLayout.scaled(context, 10, min: 8, max: 14)),
          // App Logo
          Align(
            alignment: Alignment.center,
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(logoRadius),
              ),
              child: Padding(
                padding: EdgeInsets.all(logoPadding),
                child: Image.asset(
                  'assets/images/ayah.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: headerGap),
          // App Name
          Align(
            alignment: Alignment.center,
            child: Text(
              'Quran App',
              style: TextStyle(
                fontSize: appNameSize,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(height: titleGap),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: versionSize,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: sectionGap),
          // Policy links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Privacy Policy'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
              SizedBox(
                  width: ResponsiveLayout.scaled(context, 12, min: 8, max: 16)),
              TextButton(
                onPressed: () {},
                child: const Text('Terms of Use'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          // Description card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(
                ResponsiveLayout.scaled(context, 16, min: 12, max: 20)),
            child: Text(
              "The app's name is derived from the saying: \u00ABConvey from me even an Ayah\u00BB.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: sectionGap),
          // Share/Review card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.scaled(context, 16,
                          min: 12, max: 20),
                      vertical: ResponsiveLayout.scaled(context, 10,
                          min: 8, max: 14)),
                  title: Text(
                    'Share App',
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    final message =
                        'Check out Quran App — a beautiful Mushaf with audio, bookmarks, and daily inspiration.';
                    Share.share(message, subject: 'Quran App');
                  },
                ),
              ],
            ),
          ),
          SizedBox(
              height: ResponsiveLayout.scaled(context, 32, min: 22, max: 42)),
        ],
      ),
    );
  }
}
