import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:quran_app/core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/quran/widgets/quran_pageview.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';

class PageSettingsSheet extends StatefulWidget {
  const PageSettingsSheet({super.key});

  @override
  State<PageSettingsSheet> createState() => _PageSettingsSheetState();
}

class _PageSettingsSheetState extends State<PageSettingsSheet> {
  final MushafSettingsService _mushafSettings = MushafSettingsService();
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      minChildSize: 0.5,
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      builder: (context, controller) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            ScrollMode mode = _mushafSettings.scrollMode;
            ThemeMode themeMode = _themeService.themeMode;
            SurahHeaderStyle surahStyle = _themeService.surahHeaderStyle;

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Page Settings',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: BrandColors.accent),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          controller: controller,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Scroll Direction',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _SettingOptionTile(
                                  label: 'Horizontal',
                                  icon: Icons.view_day,
                                  selected: mode == ScrollMode.horizontal,
                                  onTap: () {
                                    _mushafSettings
                                        .setScrollMode(ScrollMode.horizontal);
                                    setStateSheet(
                                        () => mode = ScrollMode.horizontal);
                                    // Trigger rebuild of parent is handled by listeners in the views
                                  },
                                ),
                                const SizedBox(width: 12),
                                _SettingOptionTile(
                                  label: 'Vertical',
                                  icon: Icons.view_stream,
                                  selected: mode == ScrollMode.vertical,
                                  onTap: () {
                                    _mushafSettings
                                        .setScrollMode(ScrollMode.vertical);
                                    setStateSheet(
                                        () => mode = ScrollMode.vertical);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Theme Mode',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: ThemeMode.values
                                  .where((t) => t != ThemeMode.system)
                                  .map((t) {
                                final selected = t == themeMode;
                                String label;
                                IconData icon;
                                switch (t) {
                                  case ThemeMode.light:
                                    label = 'Light';
                                    icon = Icons.wb_sunny;
                                    break;
                                  case ThemeMode.dark:
                                    label = 'Dark';
                                    icon = Icons.nightlight_round;
                                    break;
                                  default:
                                    label = '';
                                    icon = Icons.error;
                                }

                                return _ThemeModeTile(
                                  label: label,
                                  icon: icon,
                                  selected: selected,
                                  onTap: () {
                                    _themeService.setThemeMode(t);
                                    setStateSheet(() => themeMode = t);
                                  },
                                );
                              }).toList(),
                            ),
                            if (themeMode == ThemeMode.dark) ...[
                              const SizedBox(height: 18),
                              Text(
                                AppLocalizations.of(context)
                                        ?.translate('dark_mode_options') ??
                                    'Dark Mode Options',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                title: Text(
                                  AppLocalizations.of(context)?.translate(
                                          'pure_black_background') ??
                                      'Pure Black Background',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  AppLocalizations.of(context)?.translate(
                                          'pure_black_mushaf_short') ??
                                      'Use pure black for Mushaf',
                                ),
                                value: _themeService.pureBlackBackground,
                                onChanged: (value) {
                                  _themeService.setPureBlackBackground(value);
                                  setStateSheet(() {});
                                },
                                activeColor: BrandColors.accent,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                            if (themeMode != ThemeMode.dark) ...[
                              const SizedBox(height: 18),
                              Text(
                                AppLocalizations.of(context)
                                        ?.translate('surah_header_style') ??
                                    'Surah Header Style',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: SurahHeaderStyle.values.map((s) {
                                  final selected = s == surahStyle;
                                  String label = s == SurahHeaderStyle.golden
                                      ? 'Golden'
                                      : 'Green';
                                  return _ThemeModeTile(
                                    label: label,
                                    icon: Icons.image,
                                    selected: selected,
                                    onTap: () {
                                      _themeService.setSurahHeaderStyle(s);
                                      setStateSheet(() => surahStyle = s);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              'Language',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  const [Locale('en'), Locale('ar')].map((loc) {
                                final isSel = LanguageService()
                                        .currentLocale
                                        .languageCode ==
                                    loc.languageCode;
                                final label = loc.languageCode == 'ar'
                                    ? 'العربية'
                                    : 'English';
                                return ChoiceChip(
                                  selected: isSel,
                                  label: Text(label),
                                  selectedColor:
                                      BrandColors.accent.withOpacity(0.18),
                                  onSelected: (v) async {
                                    await LanguageService().setLocale(loc);
                                    setStateSheet(() {});
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            FutureBuilder<bool>(
                                future: SharedPreferences.getInstance().then(
                                    (p) =>
                                        p.getBool('search_gesture_enabled') ??
                                        false),
                                builder: (context, snapshot) {
                                  bool enabled = snapshot.data ?? false;
                                  return Row(
                                    children: [
                                      Expanded(
                                          child: Text(
                                        AppLocalizations.of(context)?.translate(
                                                'two_finger_search') ??
                                            'Two-finger Search',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      )),
                                      Switch.adaptive(
                                        value: enabled,
                                        onChanged: (val) async {
                                          setStateSheet(() => enabled = val);
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          await prefs.setBool(
                                              'search_gesture_enabled', val);
                                        },
                                        activeColor: BrandColors.accent,
                                      ),
                                    ],
                                  );
                                }),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SettingOptionTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? BrandColors.accent.withOpacity(0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: selected
                    ? BrandColors.accent
                    : Colors.grey.withOpacity(0.3))),
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: BrandColors.accent),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600))
                ]))),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeModeTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 84,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected
                    ? BrandColors.accent
                    : Colors.grey.withOpacity(0.3),
                width: selected ? 2 : 1)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? BrandColors.accent : Colors.grey),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? BrandColors.accent : null))
        ]),
      ),
    );
  }
}
