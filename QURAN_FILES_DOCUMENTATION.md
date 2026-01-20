# Quran App - Full Developer Guide

This guide onboards new engineers. It explains the app purpose, startup flow, architecture, data model, key services, feature modules, assets, and the critical files to touch or avoid. Keep it updated as features evolve.

## Quick Start

- Flutter via FVM **3.38.0**. Install dependencies then run: `fvm flutter pub get` and `fvm flutter run` (run from `quran_app/`).
- State: `provider` with `ChangeNotifier` (no Redux/BLoC). Persistence via `sqflite` + `SharedPreferences`.
- Heavy assets: 604 QCF page fonts plus images; `pubspec.yaml` must list them or Mushaf rendering will break.

## Boot Sequence

1. Entrypoint [quran_app/lib/main.dart](quran_app/lib/main.dart).
2. Database bootstrap: [core/database/init_database.dart](quran_app/lib/core/database/init_database.dart) -> opens `quran_app.db`, initializes Translation/Tafsir services.
3. Theme load: [core/services/theme_service.dart](quran_app/lib/core/services/theme_service.dart) reads `app_theme` from SharedPreferences.
4. Mushaf settings: [core/services/mushaf_settings_service.dart](quran_app/lib/core/services/mushaf_settings_service.dart) loads persisted scroll mode.
5. Audio notification channel: [core/services/audio_notification_service.dart](quran_app/lib/core/services/audio_notification_service.dart).
6. Home widget sync: [core/services/home_widget_service.dart](quran_app/lib/core/services/home_widget_service.dart) schedules Android Workmanager refresh for the last-read ayah.
7. Wakelock on (`wakelock_plus`).
8. Providers registered: `BookmarkNotesNotifier` (bookmarks/notes + khatmah pin). MaterialApp routes from [app/router.dart](quran_app/lib/app/router.dart).

## Architecture

- `lib/app/` routing only.
- `lib/core/` cross-cutting: database, services (theme, mushaf settings, translations, tafsir, audio, notifications, home widget), constants, Quran rendering primitives.
- `lib/features/` feature-first modules: `mushaf`, `audio_player`, `bookmarks`, `downloads`, `search`, `settings`, `tafsir` (and more as added). Each module owns its UI/state and leans on `core` services.
- `lib/data/` remote APIs, models, repositories (translations/tafsir/audio/search/chapter metadata).

## Database Schema (sqflite)

Defined in [core/database/app_database.dart](quran_app/lib/core/database/app_database.dart) (version 3):

- `ayahs`: basic ayah rows (id, surah_number, ayah_number, page, juz, text).
- `translations`: surah/ayah + language + translator + edition_identifier; unique per (surah, ayah, language, translator).
- `tafsir`: surah/ayah + language + scholar + edition_identifier; unique per (surah, ayah, language, scholar).
- `bookmarks`: surah_id, ayah_id, color_hex, category_name, is_khatmah_pin (unique single pin), timestamps.
- `notes`: personal notes per surah/ayah with timestamps.
- `metadata`: generic key/value store.
  Migrations: v2 added `edition_identifier`; v3 recreated bookmarks/notes with pin and timestamps.

## Core Services

- Theme: [core/services/theme_service.dart](quran_app/lib/core/services/theme_service.dart)
  - Four themes (Golden Parchment, Midnight Blueprint, Mint Garden, Ornate Twilight) with paired mainframe images. Persists `app_theme`.
- Mushaf settings: [core/services/mushaf_settings_service.dart](quran_app/lib/core/services/mushaf_settings_service.dart)
  - Persists `mushaf_scroll_mode` (horizontal/vertical) and exposes toggle.
- Translations: [core/services/translation_service.dart](quran_app/lib/core/services/translation_service.dart)
  - Fetch available editions, download full editions (with progress callback) via `TranslationApi`, batch insert into SQLite, track selected edition id in SharedPreferences (`selected_translation_id`), query per ayah, delete editions.
- Tafsir: [core/services/tafsir_service.dart](quran_app/lib/core/services/tafsir_service.dart)
  - Same pattern as translations; selection key `selected_tafsir_id`.
- Audio playback: [core/services/audio_player_service.dart](quran_app/lib/core/services/audio_player_service.dart)
  - Wraps `audioplayers`; prefers local downloads via `AudioService`; exposes `ValueNotifier` state (`isPlaying`, `currentLabel`); default reciter Mishary Alafasy (id 7); integrates with notification service.
- Audio notifications: [core/services/audio_notification_service.dart](quran_app/lib/core/services/audio_notification_service.dart)
  - Notification channel `quran_audio`; handles play/pause/stop actions and mirrors `AudioPlayerService` state.
- Home widget sync: [core/services/home_widget_service.dart](quran_app/lib/core/services/home_widget_service.dart)
  - Android Workmanager task `com.quran_app.widget.refresh` every 6h; writes `_last_surah`/`_last_ayah` to OS widget using `home_widget`; uses `BookmarkNotesRepository` to read khatmah pin.
- Notifications for downloads: [core/services/notification_service.dart](quran_app/lib/core/services/notification_service.dart) (used by downloads to show progress).

## Quran Rendering (Core Quran Module)

Data (constants):

- [lib/core/quran/data/juzs.dart](quran_app/lib/core/quran/data/juzs.dart) — 30 Juz with verse ranges.
- [lib/core/quran/data/page_data.dart](quran_app/lib/core/quran/data/page_data.dart) — 604-page Medina Mushaf mapping (surah, start/end ayah per page).
- [lib/core/quran/data/page_font_size.dart](quran_app/lib/core/quran/data/page_font_size.dart) — responsive font sizes per page with numerous overrides; ScreenType small/medium/large.
- [lib/core/quran/data/quarters.dart](quran_app/lib/core/quran/data/quarters.dart) — 240 Hizb quarter markers.
- [lib/core/quran/data/quran_text.dart](quran_app/lib/core/quran/data/quran_text.dart) — all 6,236 ayat with QCF glyph data, diacritics, normalized text.
- [lib/core/quran/data/suwar.dart](quran_app/lib/core/quran/data/suwar.dart) — metadata for 114 surahs (names, counts, revelation place, sources, alt names).
  Helper:
- [lib/core/quran/helpers/convert_to_arabic_number.dart](quran_app/lib/core/quran/helpers/convert_to_arabic_number.dart) — Western to Eastern Arabic numeral conversion.
  Widgets:
- [lib/core/quran/widgets/header_widget.dart](quran_app/lib/core/quran/widgets/header_widget.dart) — decorative surah header using mainframe image and `arsura` font.
- [lib/core/quran/widgets/qcf_verse.dart](quran_app/lib/core/quran/widgets/qcf_verse.dart) — renders a single ayah with correct QCF page font, RTL, dynamic font size, long-press hooks, custom background per ayah.
- [lib/core/quran/widgets/quran_pageview.dart](quran_app/lib/core/quran/widgets/quran_pageview.dart) — `PageviewQuran` supporting `ScrollMode.horizontal|vertical`, builds 604 pages from `pageData`, injects surah headers, exposes callbacks for per-ayah gestures/backgrounds.

## Mushaf Feature (Reading)

- Controller: [features/mushaf/controller/mushaf_controller.dart](quran_app/lib/features/mushaf/controller/mushaf_controller.dart)
  - Tracks scroll mode, current page/surah, bookmarked verses (string key `surah:ayah`), transient highlight.
- Screen: [features/mushaf/screens/mushaf_screen.dart](quran_app/lib/features/mushaf/screens/mushaf_screen.dart)
  - AppBar: toggle scroll mode, bookmark badge/dialog, jump-to-surah menu. Body swaps horizontal/vertical views; vertical FAB scroll-to-top.
- Horizontal view: [features/mushaf/widgets/horizontal_mushaf_view.dart](quran_app/lib/features/mushaf/widgets/horizontal_mushaf_view.dart)
  - RTL `PageviewQuran` with snap paging; overlay nav (prev/next, page indicator); long-press bottom sheet (bookmark, audio, tafsir, share); highlights bookmarks (yellow) and active press (blue).
- Vertical view: [features/mushaf/widgets/vertical_mushaf_view.dart](quran_app/lib/features/mushaf/widgets/vertical_mushaf_view.dart)
  - Continuous scroll of all 604 pages; long-press sheet adds copy-verse action; same highlight logic.
- Optional header template (commented): [features/mushaf/widgets/mushaf_header.dart](quran_app/lib/features/mushaf/widgets/mushaf_header.dart).

## Bookmarks & Notes

- State: [features/bookmarks/state/bookmark_notes_notifier.dart](quran_app/lib/features/bookmarks/state/bookmark_notes_notifier.dart)
  - Loads all bookmarks/notes, supports toggle/save, khatmah pin (also updates home widget), search notes, filter by color.
- Repository: [features/bookmarks/data/repositories/bookmark_notes_repository.dart](quran_app/lib/features/bookmarks/data/repositories/bookmark_notes_repository.dart)
  - SQLite CRUD for bookmarks/notes with transactions, khatmah pin uniqueness, optional color filtering, batched mapping with `compute` for large sets.
- Models: [features/bookmarks/data/models/bookmark.dart](quran_app/lib/features/bookmarks/data/models/bookmark.dart), [features/bookmarks/data/models/note.dart](quran_app/lib/features/bookmarks/data/models/note.dart).
- Screen placeholder: [features/bookmarks/bookmark_screen.dart](quran_app/lib/features/bookmarks/bookmark_screen.dart) (empty scaffold to implement).

## Downloads (Translations, Tafsir, Audio)

- Main UI: [features/downloads/downloads_screen.dart](quran_app/lib/features/downloads/downloads_screen.dart)
  - Tabs: Translations, Tafsir, Audio. Lists available editions/recitations, tracks downloaded items, shows per-item progress, and uses `AppNotificationService` for foreground notifications. Respects WiFi-only preference; blocks when offline.
  - Deletes editions via services; uses `SharedPreferences` for download prefs.
- Audio per-surah download: [features/downloads/audio_surah_list_page.dart](quran_app/lib/features/downloads/audio_surah_list_page.dart)
  - Lists surahs from `ChapterApi`, downloads per surah for a chosen reciter with progress notifications, honors WiFi-only flag, records downloaded status per recitation.
- Download settings: [features/downloads/download_settings_page.dart](quran_app/lib/features/downloads/download_settings_page.dart)
  - WiFi-only toggle (default false), background downloads toggle (default true), connectivity card, link to storage management.
- Storage management: [features/downloads/storage_management_page.dart](quran_app/lib/features/downloads/storage_management_page.dart)
  - Shows downloaded translations/tafsirs/recitations (names resolved from metadata), bulk delete per category, audio size calculation via `AudioService.getRecitationSizeBytes` (translations/tafsir sizes TODO).

## Audio Player

- UI shell: [features/audio_player/audio_player_screen.dart](quran_app/lib/features/audio_player/audio_player_screen.dart) (currently empty placeholder).
- Playback logic sits in services (see Core Services section) and integrates with downloads module for offline audio.

## Tafsir & Translation Reader

- Screen: [features/tafsir/tafsir_screen.dart](quran_app/lib/features/tafsir/tafsir_screen.dart)
  - Loads selected tafsir else translation; displays HTML (via `flutter_html` with unescape). Lets users pick downloaded editions by language, download new editions with progress, and set selection. Persists last language filter per picker via SharedPreferences. Handles missing content gracefully.

## Search

- Screen: [features/search/search_screen.dart](quran_app/lib/features/search/search_screen.dart)
  - Uses `SearchRepository` to fetch results; tabs for Arabic, translations, tafsir, topics (placeholder list). Opens verse details via `VerseDetailsScreen` (in Mushaf feature). Refresh action reruns search.

## Settings

- Screen: [features/settings/settings_screen.dart](quran_app/lib/features/settings/settings_screen.dart) (routed but not detailed here; tie into ThemeService and Mushaf settings when extending).

## Home Widget (Android)

- Background task every 6h updates widget with last khatmah pin location via `HomeWidgetService`. Workmanager only runs on Android; guard new tasks with platform checks.

## Assets & Fonts

- Declared in [quran_app/pubspec.yaml](quran_app/pubspec.yaml):
  - Images: `assets/images/` (mainframe variants per theme).
  - Fonts: `arsura` (surah numbers), `versenumbers` (ayah numbers), `QCF_BSML` (basmala), **QCF_P001–QCF_P604** page fonts under `assets/fonts/qcf/` (required for `QcfVerse`).

## Background Work and Notifications

- Downloads: Foreground notifications per item (progress + completion) via `AppNotificationService` (local notifications). WiFi-only preference enforced before downloads.
- Home widget refresh: Workmanager periodic task `refresh-widget-task`.
- Audio: Now-playing notification with controls using `audio_notification_service`.

## Testing & Debugging Notes

- Default Flutter test scaffold only (`flutter_test`, `flutter_lints`). No custom harness.
- Database issues: ensure `initializeDatabase()` runs; watch console logs for migration/debug prints. Translations/tafsir queries return “not available” message if edition not downloaded.
- Asset issues: missing QCF fonts -> blank/misrendered ayat; confirm `pubspec.yaml` entries.
- Connectivity gating: WiFi-only download setting lives in SharedPreferences (`download_wifi_only`).

## Routes (router.dart)

- `/` -> `MushafScreen`
- `/settings` -> `SettingsScreen`
- Route constants also declared for bookmarks/tafsir/audio/downloads/search (stubs until wired).

## Detailed File Index (Core Quran + Mushaf)

1. [lib/core/quran/data/juzs.dart](quran_app/lib/core/quran/data/juzs.dart) — Juz definitions.
2. [lib/core/quran/data/page_data.dart](quran_app/lib/core/quran/data/page_data.dart) — 604-page mapping.
3. [lib/core/quran/data/page_font_size.dart](quran_app/lib/core/quran/data/page_font_size.dart) — per-page font sizing logic.
4. [lib/core/quran/data/quarters.dart](quran_app/lib/core/quran/data/quarters.dart) — Hizb quarter markers.
5. [lib/core/quran/data/quran_text.dart](quran_app/lib/core/quran/data/quran_text.dart) — full Quran text with QCF data.
6. [lib/core/quran/data/suwar.dart](quran_app/lib/core/quran/data/suwar.dart) — surah metadata.
7. [lib/core/quran/helpers/convert_to_arabic_number.dart](quran_app/lib/core/quran/helpers/convert_to_arabic_number.dart) — numeral converter.
8. [lib/core/quran/widgets/header_widget.dart](quran_app/lib/core/quran/widgets/header_widget.dart) — surah header widget.
9. [lib/core/quran/widgets/qcf_verse.dart](quran_app/lib/core/quran/widgets/qcf_verse.dart) — ayah renderer with QCF fonts.
10. [lib/core/quran/widgets/quran_pageview.dart](quran_app/lib/core/quran/widgets/quran_pageview.dart) — Mushaf page builder (horizontal/vertical).
11. [lib/features/mushaf/controller/mushaf_controller.dart](quran_app/lib/features/mushaf/controller/mushaf_controller.dart) — Mushaf state.
12. [lib/features/mushaf/screens/mushaf_screen.dart](quran_app/lib/features/mushaf/screens/mushaf_screen.dart) — main reading screen.
13. [lib/features/mushaf/widgets/horizontal_mushaf_view.dart](quran_app/lib/features/mushaf/widgets/horizontal_mushaf_view.dart) — horizontal page mode.
14. [lib/features/mushaf/widgets/mushaf_header.dart](quran_app/lib/features/mushaf/widgets/mushaf_header.dart) — optional header template (commented).
15. [lib/features/mushaf/widgets/vertical_mushaf_view.dart](quran_app/lib/features/mushaf/widgets/vertical_mushaf_view.dart) — vertical scroll mode.

## Contributor Tips

- When adding routes, update `router.dart` and register any new providers in `AppBootstrap` if stateful.
- For new downloads, follow translation/tafsir pattern: remote API -> batch insert via DAO -> preference key for selection -> UI progress + notifications.
- Background tasks: keep Android-only guard; avoid scheduling on iOS/macOS.
- Always declare new assets/fonts in `pubspec.yaml`.
- Keep `page_data`, QCF fonts, and `page_font_size` in sync with Mushaf pagination; UI assumes Medina Mushaf (604 pages).

# Quran App – Developer Guide & File Map

This document is the on-ramp for new developers. It explains the apps purpose, how it starts up, where things live, and the critical files and data sets that power the Mushaf experience. Keep this next to your editor when you work.

## Quick Start (Environment & Commands)

- Flutter is managed with FVM. Required version: **3.38.0**.
- Install deps and run: `fvm flutter pub get` then `fvm flutter run`.
- Uses `sqflite` for persistence, `provider`/`ChangeNotifier` for state, `workmanager` for background tasks, `flutter_local_notifications` for audio controls, and heavy QCF font assets.

## App Lifecycle (Boot Sequence)

- Entrypoint: [quran_app/lib/main.dart](quran_app/lib/main.dart).
- Startup steps:
  - Initialize SQLite via `DatabaseInitializer.initializeDatabase()` ([core/database/init_database.dart](quran_app/lib/core/database/init_database.dart)) which also initializes translation and tafsir services.
  - Load theme preferences via `ThemeService.initialize()` and Mushaf scroll mode via `MushafSettingsService.initialize()`.
  - Init audio notification handling (`AudioNotificationService.init()`).
  - Start home-screen widget sync for last read ayah via `HomeWidgetService.initializeBackgroundSync()` (Android, Workmanager periodic task).
  - Enable `WakelockPlus` to keep the screen awake.
  - Bootstraps providers (currently `BookmarkNotesNotifier`) then builds `MaterialApp` with routes from [app/router.dart](quran_app/lib/app/router.dart).

## Architecture Overview

- `lib/app/router.dart`: Route table; `/` -> `MushafScreen`, `/settings` -> `SettingsScreen`; placeholders for bookmarks/tafsir/audio/search/downloads.
- `lib/core/`: Cross-cutting services, data, UI primitives, and constants.
  - `core/quran/`: Data + rendering widgets for the Mushaf pages (see detailed section below).
  - `core/database/`: `AppDatabase` (sqflite), `init_database.dart` bootstraps DB and seeds services.
  - `core/services/`: Persistent settings (theme, Mushaf scroll), translations/tafsir download + lookup, audio playback wrapper + notifications, home widget sync.
  - `core/constants/`: Theme colors, etc.
- `lib/features/`: Feature-first structure. Key modules: `mushaf/` (reading UI), `audio_player/`, `bookmarks/`, `downloads/`, `search/`, `settings/`, `tafsir/`.
- State: `provider` ChangeNotifiers (`MushafController`, `BookmarkNotesNotifier`, theme/settings services). No global BLoC/redux.

## Persistence & Remote Data

- SQLite via `sqflite`; DAOs live under `core/database/dao`. Translation and tafsir rows stored per edition; queried by surah/ayah.
- Translations: [core/services/translation_service.dart](quran_app/lib/core/services/translation_service.dart)
  - Fetches editions/languages from remote `TranslationApi`.
  - Downloads full editions, batch inserts into SQLite, tracks selected edition in `SharedPreferences` (`selected_translation_id`).
  - If verse translation missing, instructs user to download from Downloads screen.
- Tafsir: [core/services/tafsir_service.dart](quran_app/lib/core/services/tafsir_service.dart)
  - Similar flow: fetch editions, download full tafsir, batch insert, selection saved as `selected_tafsir_id`.
- Settings: `SharedPreferences` keys: `mushaf_scroll_mode`, `app_theme`, translation/tafsir selections.

## Audio Stack

- [core/services/audio_player_service.dart](quran_app/lib/core/services/audio_player_service.dart)
  - Wraps `audioplayers` with reciter selection (default Mishary Alafasy), keeps `ValueNotifier` state (`isPlaying`, `currentLabel`).
  - Streams URLs from `AudioApi`; prefers local cached files via `AudioService` when available.
  - Keeps Android/iOS notification in sync through `AudioNotificationService` (play/pause/stop actions).
- [core/services/audio_notification_service.dart](quran_app/lib/core/services/audio_notification_service.dart)
  - Sets up notification channel `quran_audio`, responds to action taps by delegating to `AudioPlayerService` (play/pause/stop), keeps now-playing card updated.

## Home Widget & Background Work

- [core/services/home_widget_service.dart](quran_app/lib/core/services/home_widget_service.dart)
  - Android-only periodic Workmanager task (`com.quran_app.widget.refresh`) runs every 6 hours to sync last-read ayah into the OS widget (`LastReadWidgetProvider`).
  - Uses `BookmarkNotesRepository` to read pinned khatmah location, writes `_last_surah`/`_last_ayah` keys via `home_widget` and triggers widget refresh.

## Theming

- [core/services/theme_service.dart](quran_app/lib/core/services/theme_service.dart)
  - Four named themes (Golden Parchment, Midnight Blueprint, Mint Garden, Ornate Twilight) mapped to themed mainframe images.
  - Persists `app_theme` in `SharedPreferences`; exposes `themeData` for `MaterialApp` and helper image paths for frame assets.

## Mushaf Settings

- [core/services/mushaf_settings_service.dart](quran_app/lib/core/services/mushaf_settings_service.dart)
  - Persists scroll mode (`horizontal`/`vertical`) across sessions; used by Mushaf screens and controller.

## Quran Rendering Stack (Core Quran Module)

- Data (pure constants, no deps):
  - `lib/core/quran/data/juzs.dart` – 30 Juz definitions with verse ranges.
  - `lib/core/quran/data/page_data.dart` – 604-page mapping of surah/ayah spans (Medina Mushaf pagination).
  - `lib/core/quran/data/page_font_size.dart` – Responsive font sizing by page and screen type (special cases for dense pages).
  - `lib/core/quran/data/quarters.dart` – 240 Hizb quarter markers (surah/ayah start points).
  - `lib/core/quran/data/quran_text.dart` – Full Quran text (6,236 ayat) with QCF glyph data, Arabic text, and normalized text.
  - `lib/core/quran/data/suwar.dart` – Metadata for 114 surahs (names, counts, place, alt names, references).
- Helpers:
  - `lib/core/quran/helpers/convert_to_arabic_number.dart` – Western to Eastern Arabic numeral conversion for UI labels.
- Widgets:
  - `lib/core/quran/widgets/header_widget.dart` – Decorative surah header using themed mainframe image.
  - `lib/core/quran/widgets/qcf_verse.dart` – Renders a single ayah with correct QCF page font, responsive sizing, long-press hooks.
  - `lib/core/quran/widgets/quran_pageview.dart` – Core page renderer supporting horizontal/vertical scroll, surah headers, verse gestures, and per-verse highlighting hooks.

## Mushaf Feature (Reading Experience)

- Controller: [lib/features/mushaf/controller/mushaf_controller.dart](quran_app/lib/features/mushaf/controller/mushaf_controller.dart)
  - Tracks scroll mode, current page/surah, bookmarks (`surah:verse`), transient highlight.
- Screen: [lib/features/mushaf/screens/mushaf_screen.dart](quran_app/lib/features/mushaf/screens/mushaf_screen.dart)
  - AppBar actions: toggle scroll mode, bookmark badge/list dialog, jump-to-surah menu.
  - Body swaps `HorizontalMushafView` vs `VerticalMushafView`; FAB for scroll-to-top in vertical mode.
- Horizontal view: [lib/features/mushaf/widgets/horizontal_mushaf_view.dart](quran_app/lib/features/mushaf/widgets/horizontal_mushaf_view.dart)
  - Uses `PageviewQuran` (snap paging, RTL). Overlay nav controls, long-press bottom sheet (bookmark/audio/tafsir/share). Highlights bookmarks (yellow) and active press (blue).
- Vertical view: [lib/features/mushaf/widgets/vertical_mushaf_view.dart](quran_app/lib/features/mushaf/widgets/vertical_mushaf_view.dart)
  - Continuous scroll of all 604 pages; long-press sheet adds copy verse text option; highlights similar to horizontal.
- Optional header variant template: [lib/features/mushaf/widgets/mushaf_header.dart](quran_app/lib/features/mushaf/widgets/mushaf_header.dart) (currently commented out).

## Audio, Tafsir, Translation Features (Pointers)

- Audio player UI lives under `lib/features/audio_player/` (uses `AudioPlayerService` and notification service).
- Downloads flow (translations/tafsir/audio) lives under `lib/features/downloads/` with remote APIs in `lib/data/sources/remote/`.
- Bookmarks and notes: `lib/features/bookmarks/` with repository `BookmarkNotesRepository` (used by widget sync); notes state in `BookmarkNotesNotifier` registered at app boot.
- Search & Tafsir screens: `lib/features/search/`, `lib/features/tafsir/` (routes to be wired in `router.dart`).

## Assets & Fonts

- Declared in [pubspec.yaml](quran_app/pubspec.yaml):
  - Images: `assets/images/` (mainframe variants for themes).
  - Fonts: `assets/fonts/qcf/` contains 604 QCF page fonts (QCF_P001  QCF_P604), `assets/fonts/QCF2BSMLfonts/` basmala font, `arsura` (surah number), `versenumbers` (ayah numbers).
- These assets are essential for accurate Uthmanic rendering; missing fonts will break `QcfVerse`.

## Testing & Debug Notes

- No custom test harness documented; default Flutter test setup present (`flutter_test`, `flutter_lints`).
- When debugging missing data, ensure DB init ran and translation/tafsir downloads completed; services log to console on errors.

## Detailed File Reference (Core Quran & Mushaf)

### Core Quran Data Files

1. `lib/core/quran/data/juzs.dart`
   - 30 Juz definitions with surah lists and ayah ranges.
2. `lib/core/quran/data/page_data.dart`
   - 604-page mapping (surah + start/end ayah) for Medina Mushaf layout.
3. `lib/core/quran/data/page_font_size.dart`
   - `ScreenType` enum; `getFontSize(page, context)` adjusts for device size/orientation with many page-specific overrides (e.g., pages 1-2 size 25).
4. `lib/core/quran/data/quarters.dart`
   - 240 quarter markers (Hizb) as surah/ayah start positions.
5. `lib/core/quran/data/quran_text.dart`
   - Full Quran text with QCF glyphs, diacritics, normalized text, per-ayah metadata.
6. `lib/core/quran/data/suwar.dart`
   - Surah metadata (id, names in multiple languages, aya count, revelation place, sources, alt names).

### Core Quran Helper

7. `lib/core/quran/helpers/convert_to_arabic_number.dart`
   - Maps Western digits to Eastern Arabic numerals.

### Core Quran Widgets

8. `lib/core/quran/widgets/header_widget.dart`
   - Decorative surah header using themed frame image and `arsura` font; responsive sizing.
9. `lib/core/quran/widgets/qcf_verse.dart`
   - Loads correct QCF page font per ayah, RTL text, adjustable font size via `getFontSize`, gesture hooks for long-press lifecycle, accepts per-verse background color.
10. `lib/core/quran/widgets/quran_pageview.dart`
    - `PageviewQuran` with `ScrollMode` (`horizontal`/`vertical`); builds 604 pages using `_PageContent`.
    - Adds surah headers when a page starts a surah; iterates `pageData` to render verses with `QcfVerse`.
    - Exposes callbacks: `onPageChanged`, per-verse long-press/down/up/cancel, `verseBackgroundColor` resolver.

### Mushaf Feature Files

11. `lib/features/mushaf/controller/mushaf_controller.dart`
    - ChangeNotifier for Mushaf state: scroll mode, current page/surah, bookmarks set, highlight pair.
12. `lib/features/mushaf/screens/mushaf_screen.dart`
    - Scaffold with AppBar actions (mode toggle, bookmark list badge, jump-to-surah), FAB for scroll-to-top (vertical mode), wires controller into views.
13. `lib/features/mushaf/widgets/horizontal_mushaf_view.dart`
    - Stack of `PageviewQuran` + bottom navigation overlay; long-press sheet options: bookmark/audio/tafsir/share; visual highlights for bookmarks/selection.
14. `lib/features/mushaf/widgets/mushaf_header.dart`
    - Commented template for richer surah header card (kept for future use).
15. `lib/features/mushaf/widgets/vertical_mushaf_view.dart`
    - Continuous scroll `PageviewQuran`; long-press adds copy-verse action; same highlight logic as horizontal.

## Contributor Notes

- Keep new assets registered in `pubspec.yaml` or QCF loading will fail.
- When adding routes, update [app/router.dart](quran_app/lib/app/router.dart) and ensure providers are registered in `AppBootstrap` if stateful.
- Background work runs only on Android; guard platform checks when adding tasks.
- For new download flows, follow translation/tafsir pattern: remote API -> batch insert via DAO -> preference key for selection.

# Quran App - Files Documentation

This document provides a comprehensive overview of all files in the `core/quran` and `features/mushaf` directories.

## Table of Contents

- [Core Quran Files](#core-quran-files)
  - [Data Files](#data-files)
  - [Helper Files](#helper-files)
  - [Widget Files](#widget-files)
- [Features Mushaf Files](#features-mushaf-files)
  - [Controller Files](#controller-files)
  - [Screen Files](#screen-files)
  - [Widget Files (Mushaf)](#widget-files-mushaf)

---

# Core Quran Files

## Data Files

### 1. `lib/core/quran/data/juzs.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\data\juzs.dart`  
**Lines:** 356  
**Size:** 5,540 bytes

**Purpose:**  
Contains data structure for all 30 Juz (parts) of the Quran.

**Content:**

- A constant list `juz` containing 30 Map objects
- Each Juz entry contains:
  - `id`: Juz number (1-30)
  - `surahs`: List of Surah numbers contained in this Juz
  - `verses`: Map of Surah numbers to verse ranges [start, end]

**Example Structure:**

```dart
{
  "id": 1,
  "surahs": [1, 2],
  "verses": {
    1: [1, 7],
    2: [1, 141]
  }
}
```

**Usage:**  
Used to navigate and display Quran content by Juz divisions, allowing users to read the Quran in 30 equal parts.

---

### 2. `lib/core/quran/data/page_data.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\data\page_data.dart`  
**Lines:** 1,900  
**Size:** 35,873 bytes

**Purpose:**  
Contains comprehensive page-by-page mapping of Quran verses for Mushaf rendering.

**Content:**

- A constant list `pageData` containing 604 page entries (standard Mushaf pagination)
- Each page entry contains:
  - `surah`: Surah number
  - `start`: Starting verse number
  - `end`: Ending verse number
- Some pages contain multiple Surah segments when a Surah boundary occurs

**Example Structure:**

```dart
[
  {"surah": 1, "start": 1, "end": 7}  // Page 1: Complete Al-Fatiha
],
[
  {"surah": 2, "start": 1, "end": 5}   // Page 2: Al-Baqarah verses 1-5
]
```

**Usage:**  
Essential for rendering the Quran in traditional Mushaf page format (604 pages), enabling accurate page-based navigation and display.

---

### 3. `lib/core/quran/data/page_font_size.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\data\page_font_size.dart`  
**Lines:** 93  
**Size:** 2,272 bytes

**Purpose:**  
Dynamically calculates optimal font sizes for different pages and screen configurations.

**Content:**

**Enum:**

```dart
enum ScreenType { small, medium, large }
```

**Functions:**

1. **`getScreenType(BuildContext context)`**

   - Returns: `ScreenType`
   - Determines screen size category based on width:
     - Small: < 360px
     - Medium: 360-600px
     - Large: > 600px

2. **`getFontSize(int index, BuildContext context)`**
   - Returns: `double`
   - Parameters:
     - `index`: Page number
     - `context`: Build context for screen info
   - Contains special font size mappings for specific pages
   - Adjusts based on:
     - Screen orientation (landscape vs portrait)
     - Screen type
     - Specific page requirements (e.g., page 1, 2 have larger fonts at 25)
     - Default size: 23.1

**Special Page Sizes:**

- Pages 1-2: 25 (Al-Fatiha needs larger text)
- Pages 145, 585: 22.7
- Page 532, 533, 523, 577: 22.5
- Many individual page adjustments for optimal readability

**Usage:**  
Ensures optimal text rendering across different devices and pages, accounting for varying verse densities on different pages.

---

### 4. `lib/core/quran/data/quarters.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\data\quarters.dart`  
**Lines:** 961  
**Size:** 14,564 bytes

**Purpose:**  
Contains data for Hizb markers (quarter divisions) throughout the Quran.

**Content:**

- A list `quarters` containing 240 entries (60 Hizb × 4 quarters = 240)
- Each quarter entry contains:
  - `surah`: Surah number where the quarter starts
  - `ayah`: Verse number where the quarter starts

**Example Structure:**

```dart
{
  "surah": 1,
  "ayah": 1
},
{
  "surah": 2,
  "ayah": 26
}
```

**Usage:**  
Enables displaying Hizb/quarter markers in the Quran interface, allowing users to track their reading progress using traditional Hizb divisions (commonly used for memorization and daily reading schedules).

---

### 5. `lib/core/quran/data/quran_text.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\data\quran_text.dart`  
**Lines:** 54,045  
**Size:** 3,368,671 bytes (~3.2 MB)

**Purpose:**  
Contains the complete text of the Quran with QCF (Quran Complex Font) data for proper rendering.

**Content:**

- A constant list `quranText` containing 6,236 verse entries (all verses of the Quran)
- Each verse entry contains:
  - `surah_number`: Surah number (1-114)
  - `verse_number`: Verse number within the Surah
  - `qcfData`: QCF font encoded text for proper Uthmanic rendering
  - `content`: Standard Arabic text with diacritics
  - `text_normal`: Simplified Arabic text without special marks
  - `qcfv4data`: QCF version 4 specific data

**Example Structure:**

```dart
{
  "surah_number": 1,
  "verse_number": 1,
  "qcfData": "ﱁﱂﱃﱄﱅ",
  "content": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
  "text_normal": "بسم الله الرحمن الرحيم",
  "qcfv4data": "ﱅ"
}
```

**Usage:**  
The core data file for displaying Quran text using QCF fonts, which ensures proper Uthmanic script rendering matching the printed Mushaf. The QCF data enables pixel-perfect text display that matches the official Medina Mushaf.

---

### 6. `lib/core/quran/data/suwar.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\data\suwar.dart`  
**Lines:** 1,493  
**Size:** 434,107 bytes (~424 KB)

**Purpose:**  
Contains comprehensive metadata for all 114 Surahs of the Quran.

**Content:**

- A constant list `surah` containing 114 Surah entries
- Each Surah entry contains:
  - `id`: Surah number (1-114)
  - `name`: English transliteration name
  - `aya`: Number of verses in the Surah
  - `english`: English translation of the name
  - `turkish`: Turkish name
  - `place`: Revelation place (Makkah or Madinah)
  - `arabic`: Arabic name
  - `surahInfo`: Detailed information about the Surah
  - `surahInfoFromBook`: Source reference
  - `surahNames`: Alternative names for the Surah
  - `surahNamesFromBook`: Source for alternative names

**Example Structure:**

```dart
{
  "id": 1,
  "name": "Al Fatiha",
  "aya": 7,
  "english": "The Opening",
  "turkish": "Fâtiha",
  "place": "Makkah",
  "arabic": "الفاتحة",
  "surahInfoFromBook": "كتاب فتح القدير [الشوكاني]",
  "surahNamesFromBook": "كتاب الإتقان في علوم القرآن [الجلال السيوطي]"
}
```

**Usage:**  
Provides comprehensive Surah information for navigation, display, and educational purposes. Used in Surah selection menus, headers, and information displays.

---

## Helper Files

### 7. `lib/core/quran/helpers/convert_to_arabic_number.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\helpers\convert_to_arabic_number.dart`  
**Lines:** 16  
**Size:** 328 bytes

**Purpose:**  
Utility function to convert Western (Arabic) numerals to Eastern Arabic numerals.

**Content:**

**Function:**

```dart
String convertToArabicNumber(String number)
```

**Parameters:**

- `number`: String containing Western numerals (0-9)

**Returns:**

- String with Eastern Arabic numerals (٠-٩)

**Implementation:**

- Maps each digit:
  - 0 → ٠
  - 1 → ١
  - 2 → ٢
  - 3 → ٣
  - 4 → ٤
  - 5 → ٥
  - 6 → ٦
  - 7 → ٧
  - 8 → ٨
  - 9 → ٩

**Usage:**  
Converts page numbers, verse numbers, and Surah numbers to Eastern Arabic numerals for a more authentic Arabic interface experience.

---

## Widget Files

### 8. `lib/core/quran/widgets/header_widget.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\widgets\header_widget.dart`  
**Lines:** 42  
**Size:** 1,202 bytes

**Purpose:**  
Displays decorative Surah header with Surah number in traditional style.

**Content:**

**Class:** `HeaderWidget extends StatelessWidget`

**Constructor:**

```dart
const HeaderWidget({super.key, required this.suraNumber})
```

**Properties:**

- `suraNumber`: int - The Surah number to display

**Build Method:**

- Returns an `InkWell` widget with tap interaction
- Contains:
  - Background image: "assets/images/mainframe.png"
  - Surah number displayed using "arsura" font family
  - Responsive sizing based on screen type
    - Large screens: width 250, font size 16
    - Other screens: width 372, font size 29

**Visual Features:**

- Decorative frame around Surah number
- Centered layout
- Traditional Islamic calligraphic style

**Usage:**  
Displayed at the beginning of each Surah to provide visual separation and aesthetic appeal in the Mushaf view.

---

### 9. `lib/core/quran/widgets/qcf_verse.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\widgets\qcf_verse.dart`  
**Lines:** 87  
**Size:** 2,698 bytes

**Purpose:**  
Renders individual Quranic verses using QCF (Quran Complex Font) for authentic Uthmanic script display.

**Content:**

**Class:** `QcfVerse extends StatefulWidget`

**Constructor:**

```dart
const QcfVerse({
  super.key,
  required this.surahNumber,
  required this.verseNumber,
  this.fontSize,
  this.textColor = const Color(0xFF000000),
  this.backgroundColor = const Color(0x00000000),
  this.onLongPress,
  this.onLongPressUp,
  this.onLongPressCancel,
  this.onLongPressDown,
  this.sp = 1,
  this.h = 1,
})
```

**Properties:**

- `surahNumber`: int - Surah number
- `verseNumber`: int - Verse number within the Surah
- `fontSize`: double? - Optional custom font size
- `textColor`: Color - Text color (default: black)
- `backgroundColor`: Color - Background highlight color (default: transparent)
- `onLongPress`: VoidCallback? - Long press callback
- `onLongPressUp`: VoidCallback? - Long press release callback
- `onLongPressCancel`: VoidCallback? - Long press cancel callback
- `onLongPressDown`: Function(LongPressStartDetails)? - Long press start callback
- `sp`: double - Screen pixel ratio for responsive font (default: 1)
- `h`: double - Height ratio for responsive design (default: 1)

**Key Features:**

1. **Dynamic Font Loading:**

   - Automatically determines the page number for the verse
   - Loads the corresponding QCF font: `QCF_P{pageNumber}`
   - Each page of the Quran has its own specialized font file

2. **Responsive Font Sizing:**

   - Uses `getFontSize()` to determine optimal size
   - Adjusts based on screen size using `sp` ratio

3. **Text Styling:**

   - Right-to-left (RTL) text direction
   - Center alignment
   - Custom line height: 2.0 / h
   - Verse number height: 1.35 / h
   - Zero letter and word spacing

4. **Gesture Handling:**
   - Supports long press gestures
   - Can trigger callbacks for interaction (bookmarking, highlighting, etc.)

**Usage:**  
Core widget for rendering individual Quranic verses with proper Uthmanic script. Used extensively throughout the Mushaf view to ensure authentic text display.

---

### 10. `lib/core/quran/widgets/quran_pageview.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\core\quran\widgets\quran_pageview.dart`  
**Lines:** 329  
**Size:** 11,208 bytes

**Purpose:**  
The main widget for displaying Quran pages, supporting both horizontal (page-by-page) and vertical (continuous) scrolling modes.

**Content:**

**Enum:**

```dart
enum ScrollMode { horizontal, vertical }
```

**Class:** `PageviewQuran extends StatefulWidget`

**Constructor:**

```dart
const PageviewQuran({
  super.key,
  this.initialPageNumber = 1,
  this.scrollMode = ScrollMode.horizontal,
  this.onPageChanged,
  this.textColor = Colors.black,
  this.pageBackgroundColor = Colors.white,
  this.verseBackgroundColor,
  this.onLongPress,
  this.onLongPressDown,
  this.onLongPressUp,
  this.onLongPressCancel,
  this.sp = 1.0,
  this.h = 1.0,
})
```

**Properties:**

- `initialPageNumber`: int - Starting page (1-604)
- `scrollMode`: ScrollMode - Horizontal or vertical scrolling
- `onPageChanged`: Function(int)? - Callback when page changes
- `textColor`: Color - Color for verse text
- `pageBackgroundColor`: Color - Background color for pages
- `verseBackgroundColor`: Function(int, int)? - Dynamic background per verse
- `onLongPress`: Function(int, int)? - Long press handler (surah, verse)
- `onLongPressDown`: Function(int, int, LongPressStartDetails)? - Long press start
- `onLongPressUp`: Function(int, int)? - Long press release
- `onLongPressCancel`: Function(int, int)? - Long press cancel
- `sp`: double - Screen pixel ratio
- `h`: double - Height ratio

**State Class:** `_PageviewQuranState`

**State Properties:**

- `_pageController`: PageController for managing page navigation
- `_currentPage`: int tracking current visible page

**Key Methods:**

1. **`initState()`**

   - Initializes PageController with initial page
   - Sets up listeners and state

2. **`dispose()`**

   - Properly disposes PageController
   - Cleans up resources

3. **`build(BuildContext context)`**

   - Routes to appropriate view based on scroll mode
   - Returns horizontal or vertical view

4. **`_buildHorizontalView()`**

   - Creates PageView.builder for page-by-page navigation
   - Uses PageScrollPhysics for snap-to-page behavior
   - RTL scroll direction (reverse: true)
   - Builds 604 pages using `_PageContent` widget

5. **`_buildVerticalView()`**
   - Creates ListView.builder for continuous scrolling
   - Displays all 604 pages sequentially
   - No pagination, smooth continuous scroll

**Helper Class:** `_PageContent extends StatelessWidget`

**Purpose:** Renders a single page of the Quran

**Properties:**

- `pageNumber`: int (1-604)
- `textColor`: Color
- `backgroundColor`: Color
- `verseBackgroundColor`: Function(int, int)?
- Gesture handlers for verse interaction

**Content Rendering:**

1. **Surah Headers:**

   - Displays `HeaderWidget` when a new Surah starts
   - Checks if current page contains the first verse of any Surah

2. **Verse Rendering:**
   - Iterates through `pageData` for the current page
   - Renders each verse using `QcfVerse` widget
   - Applies dynamic background colors for highlighting/bookmarking
   - Wraps verses in gesture detection for interaction

**Page Layout:**

- Container with specified background color
- Padding: 16px all around
- Column layout for vertical stacking
- Centered content
- Responsive sizing based on screen dimensions

**Usage:**  
The primary widget for the Mushaf view. Handles:

- Page-by-page navigation (horizontal mode)
- Continuous scrolling (vertical mode)
- Verse interaction (long press, highlighting)
- Dynamic styling (colors, backgrounds)
- Surah headers
- All 604 pages of the standard Mushaf

---

# Features Mushaf Files

## Controller Files

### 11. `lib/features/mushaf/controller/mushaf_controller.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\features\mushaf\controller\mushaf_controller.dart`  
**Lines:** 69  
**Size:** 1,795 bytes

**Purpose:**  
State management controller for the Mushaf feature using Flutter's ChangeNotifier pattern.

**Content:**

**Class:** `MushafController extends ChangeNotifier`

**Private State Properties:**

```dart
ScrollMode _scrollMode = ScrollMode.horizontal;
int _currentPage = 1;
int _currentSurah = 1;
final Set<String> _bookmarkedVerses = {};
int? _highlightedSurah;
int? _highlightedVerse;
```

**Public Getters:**

- `scrollMode` → ScrollMode
- `currentPage` → int
- `currentSurah` → int
- `bookmarkedVerses` → Set<String>
- `highlightedSurah` → int?
- `highlightedVerse` → int?

**Methods:**

1. **`toggleScrollMode()`**

   - Switches between horizontal and vertical scroll modes
   - Notifies listeners of state change

2. **`setPage(int page)`**

   - Updates current page number
   - Notifies listeners

3. **`setSurah(int surah)`**

   - Updates current Surah
   - Notifies listeners

4. **`toggleBookmark(int surah, int verse)`**

   - Adds or removes bookmark for a verse
   - Bookmark format: "surah:verse" (e.g., "2:255")
   - Notifies listeners

5. **`isBookmarked(int surah, int verse)`**

   - Returns: bool
   - Checks if a verse is bookmarked

6. **`setHighlightedVerse(int? surah, int? verse)`**

   - Sets currently highlighted verse
   - Used for temporary selection during long press
   - Notifies listeners

7. **`clearHighlight()`**

   - Clears verse highlighting
   - Notifies listeners

8. **`dispose()`**
   - Clears bookmarks
   - Calls super.dispose()

**State Management Pattern:**

- Uses ChangeNotifier for reactive updates
- Notifies listeners after each state change
- Enables widgets to rebuild when state updates

**Usage:**  
Central state management for Mushaf features. Manages:

- Current page/Surah tracking
- Scroll mode preference
- Verse bookmarking
- Temporary verse highlighting
- UI updates via listener notifications

---

## Screen Files

### 12. `lib/features/mushaf/screens/mushaf_screen.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\features\mushaf\screens\mushaf_screen.dart`  
**Lines:** 175  
**Size:** 5,785 bytes

**Purpose:**  
Main screen for the Mushaf (Quran reading) interface with navigation and interaction features.

**Content:**

**Class:** `MushafScreen extends StatefulWidget`

**State Class:** `_MushafScreenState`

**State Properties:**

```dart
final MushafController _controller = MushafController();
final ScrollController _scrollController = ScrollController();
```

**AppBar Features:**

1. **Title:** "Al-Quran"
2. **Background:** Green (Colors.green[700])
3. **Actions:**

   - **Scroll Mode Toggle Button:**

     - Icon changes based on mode (view_day / view_stream)
     - Toggles between horizontal and vertical scrolling
     - Tooltip provides context

   - **Bookmark Button with Badge:**

     - Shows bookmark count badge
     - Opens bookmark list dialog
     - Only enabled when bookmarks exist

   - **Jump to Surah Menu:**
     - PopupMenuButton with all 114 Surahs
     - Allows quick navigation to any Surah

**Body:**

- Conditionally renders based on scroll mode:
  - Horizontal: `HorizontalMushafView`
  - Vertical: `VerticalMushafView`
- Passes controller and scroll controller to views

**Floating Action Button:**

- Only visible in vertical mode
- "Scroll to Top" functionality
- Arrow up icon

**Key Methods:**

1. **`build(BuildContext context)`**

   - Main build method
   - Creates Scaffold with AppBar, body, and FAB
   - Uses ListenableBuilder for reactive bookmark count

2. **`_buildFloatingActionButton()`**

   - Returns FloatingActionButton for vertical mode
   - Returns null for horizontal mode
   - Enables quick scroll to top

3. **`_scrollToTop()`**

   - Animates scroll to position 0
   - Duration: 500ms
   - Curve: easeInOut

4. **`_jumpToSurah(int surah)`**

   - Updates controller's current Surah
   - Vertical mode: Calculates approximate scroll position
   - Horizontal mode: Placeholder for page calculation
   - Animated navigation

5. **`_showBookmarks()`**

   - Shows AlertDialog with bookmarked verses
   - Lists all bookmarks in format "Surah X, Verse Y"
   - Each bookmark is tappable to navigate
   - Includes remove bookmark button
   - Shows "No bookmarked verses" if empty

6. **`_jumpToVerse(int surah, int verse)`**

   - Navigation to specific verse
   - Updates current Surah
   - Placeholder for full implementation

7. **`dispose()`**
   - Disposes scroll controller
   - Disposes Mushaf controller
   - Calls super.dispose()

**UI Features:**

- Green color theme (Islamic aesthetic)
- Badge notifications for bookmarks
- Smooth animations for navigation
- Responsive to controller state changes
- Interactive bookmark management
- Context-aware FAB display

**Usage:**  
The main entry point for Quran reading. Provides:

- Mode switching (horizontal/vertical)
- Bookmark management
- Surah navigation
- Scroll controls
- Comprehensive reading interface

---

## Widget Files (Mushaf)

### 13. `lib/features/mushaf/widgets/horizontal_mushaf_view.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\features\mushaf\widgets\horizontal_mushaf_view.dart`  
**Lines:** 191  
**Size:** 6,578 bytes

**Purpose:**  
Displays Quran in horizontal page-by-page view with navigation controls and verse interaction.

**Content:**

**Class:** `HorizontalMushafView extends StatelessWidget`

**Constructor:**

```dart
const HorizontalMushafView({super.key, required this.controller})
```

**Properties:**

- `controller`: MushafController - State management

**Build Method Structure:**

**1. Main Layout (Stack):**

- **Background Layer:** `PageviewQuran` widget
- **Overlay Layer:** Page navigation controls

**2. PageviewQuran Configuration:**

```dart
PageviewQuran(
  initialPageNumber: controller.currentPage,
  scrollMode: ScrollMode.horizontal,
  onPageChanged: (page) => controller.setPage(page),
  textColor: Colors.black,
  pageBackgroundColor: Color(0xFFF5F5DC), // Parchment color
  verseBackgroundColor: (surah, verse) { /* dynamic highlighting */ },
  onLongPress: (surah, verse) => _showVerseOptions(context, surah, verse),
  onLongPressDown: (surah, verse, details) => controller.setHighlightedVerse(surah, verse),
  onLongPressCancel: (surah, verse) => controller.clearHighlight(),
)
```

**3. Dynamic Verse Background:**

- Yellow highlight (30% opacity) for bookmarked verses
- Blue highlight (20% opacity) for currently selected verse
- Transparent otherwise

**4. Page Navigation Overlay (Positioned at bottom):**

- Left: Previous page button
- Center: Page indicator "Page X of 604"
- Right: Next page button
- Dark background with rounded corners
- Uses ListenableBuilder for reactive updates

**Key Methods:**

1. **`_buildNavigationButton(IconData icon, VoidCallback onPressed, bool enabled)`**

   - Creates circular navigation button
   - Green when enabled, grey when disabled
   - White icon
   - Circle shape

2. **`_navigateToPage(int page)`**

   - Validates page range (1-604)
   - Updates controller's current page

3. **`_showVerseOptions(BuildContext context, int surah, int verse)`**

   - Shows ModalBottomSheet with verse actions
   - **Options:**
     - Bookmark/Remove Bookmark
     - Play Audio
     - View Tafsir
     - Share Verse
     - Cancel
   - Dynamic icon/text based on bookmark status

4. **`_showBookmarkSnackbar(BuildContext context, bool wasBookmarked)`**

   - Shows confirmation message
   - "Bookmark removed" or "Verse bookmarked"
   - 2-second duration

5. **`_playAudio(int surah, int verse)`**

   - Placeholder for audio playback
   - Currently prints to console

6. **`_viewTafsir(int surah, int verse)`**

   - Placeholder for Tafsir navigation
   - Currently prints to console

7. **`_shareVerse(int surah, int verse)`**
   - Placeholder for sharing functionality
   - Currently prints to console

**Visual Design:**

- Parchment-like background (#F5F5DC)
- Black text for readability
- Green theme for controls
- Semi-transparent highlights
- Professional page indicator
- Smooth navigation animations

**Interaction Features:**

- Long press to show verse options
- Visual feedback during long press
- Bookmark highlighting
- Page-by-page navigation
- Gesture-based controls

**Usage:**  
Horizontal reading mode for Mushaf. Mimics traditional printed Quran experience with page turning and traditional layout.

---

### 14. `lib/features/mushaf/widgets/mushaf_header.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\features\mushaf\widgets\mushaf_header.dart`  
**Lines:** 131  
**Size:** 5,048 bytes

**Purpose:**  
Originally intended for enhanced Surah headers (currently commented out).

**Content:**

- Entire file is commented out
- Contains template code for a more elaborate Surah header design

**Commented Features:**

1. **Visual Elements:**

   - Circular Surah number badge
   - Green gradient background
   - Surah name in Arabic
   - Revelation location (Meccan/Medinan)
   - Verse count indicator
   - Bismillah for all Surahs except At-Tawbah (Surah 9)

2. **Layout:**

   - Card with elevation
   - Rounded corners
   - Centered content
   - Icons for location and verse count

3. **Helper Function:**
   - `_isMeccanSurah(int surahNumber)` - Determines revelation location
   - Hardcoded list of Medinan Surahs

**Current Status:**

- Not in active use
- Kept for potential future implementation
- Template for enhanced UI

**Usage:**  
Currently unused. The active header is `core/quran/widgets/header_widget.dart`. This file provides a more detailed alternative that could be activated in future updates.

---

### 15. `lib/features/mushaf/widgets/vertical_mushaf_view.dart`

**Location:** `B:\Documents\Projects\ayah_project\quran_app\lib\features\mushaf\widgets\vertical_mushaf_view.dart`  
**Lines:** 150  
**Size:** 4,777 bytes

**Purpose:**  
Displays Quran in vertical continuous scrolling view with verse interaction capabilities.

**Content:**

**Class:** `VerticalMushafView extends StatelessWidget`

**Constructor:**

```dart
const VerticalMushafView({
  super.key,
  required this.controller,
  required this.scrollController,
})
```

**Properties:**

- `controller`: MushafController - State management
- `scrollController`: ScrollController - For programmatic scrolling

**Build Method:**

Returns `PageviewQuran` configured for vertical mode:

```dart
PageviewQuran(
  initialPageNumber: controller.currentPage,
  scrollMode: ScrollMode.vertical,
  onPageChanged: (page) => controller.setPage(page),
  textColor: Colors.black,
  pageBackgroundColor: Color(0xFFF5F5DC),
  verseBackgroundColor: (surah, verse) { /* highlighting */ },
  onLongPress: (surah, verse) => _showVerseOptions(context, surah, verse),
  onLongPressDown: (surah, verse, details) => controller.setHighlightedVerse(surah, verse),
  onLongPressCancel: (surah, verse) => controller.clearHighlight(),
  sp: 1.0,
  h: 1.0,
)
```

**Key Features:**

1. **Continuous Scrolling:**

   - All 604 pages displayed sequentially
   - Smooth scroll through entire Quran
   - No page breaks

2. **Dynamic Highlighting:**
   - Yellow (30% opacity) for bookmarked verses
   - Blue (20% opacity) for selected verse
   - Transparent otherwise

**Key Methods:**

1. **`_showVerseOptions(BuildContext context, int surah, int verse)`**

   - Shows ModalBottomSheet with verse actions
   - **Options:**
     - Bookmark/Remove Bookmark
     - Play Audio
     - View Tafsir
     - Share Verse
     - Copy Verse Text (unique to vertical view)
     - Cancel
   - Dynamic UI based on bookmark status

2. **`_showBookmarkSnackbar(BuildContext context, bool wasBookmarked)`**

   - Confirmation feedback
   - 2-second duration
   - "Bookmark removed" or "Verse bookmarked"

3. **`_playAudio(int surah, int verse)`**

   - Placeholder for audio playback
   - Currently logs to console

4. **`_viewTafsir(int surah, int verse)`**

   - Placeholder for Tafsir view
   - Currently logs to console

5. **`_viewTafsir(int surah, int verse)`**

   - Placeholder for Tafsir view
   - Currently logs to console

6. **`_shareVerse(int surah, int verse)`**

   - Placeholder for sharing
   - Currently logs to console

7. **`_copyVerseText(int surah, int verse)`**
   - Placeholder for clipboard copy
   - Currently logs to console
   - **Note:** This feature is unique to vertical view

**Differences from Horizontal View:**

1. **Additional Feature:** Copy verse text option
2. **No Navigation Controls:** Relies on native scroll
3. **Continuous Layout:** No discrete page boundaries
4. **Better for Reading Long Sections:** Uninterrupted flow

**Visual Design:**

- Same parchment background (#F5F5DC)
- Consistent highlighting scheme
- Clean, distraction-free reading
- Focus on content

**Usage:**  
Vertical reading mode for continuous Quran reading. Better for:

- Long reading sessions
- Searching across pages
- Reading without page interruptions
- Modern smartphone reading patterns

---

## Summary

### Core Quran Module

**Purpose:** Provides fundamental Quran data structures and rendering capabilities.

**Data Files (6):**

1. `juzs.dart` - 30 Juz divisions
2. `page_data.dart` - 604 page mappings
3. `page_font_size.dart` - Dynamic font sizing
4. `quarters.dart` - 240 Hizb markers
5. `quran_text.dart` - Complete Quran text (6,236 verses)
6. `suwar.dart` - 114 Surah metadata

**Helper Files (1):** 7. `convert_to_arabic_number.dart` - Numeral conversion utility

**Widget Files (3):** 8. `header_widget.dart` - Surah header display 9. `qcf_verse.dart` - Individual verse rendering with QCF fonts 10. `quran_pageview.dart` - Main page view widget (horizontal/vertical)

### Features Mushaf Module

**Purpose:** Implements the Mushaf reading interface with user interactions.

**Controller Files (1):** 11. `mushaf_controller.dart` - State management (bookmarks, navigation, highlighting)

**Screen Files (1):** 12. `mushaf_screen.dart` - Main Mushaf screen with AppBar and navigation

**Widget Files (3):** 13. `horizontal_mushaf_view.dart` - Page-by-page view with controls 14. `mushaf_header.dart` - Enhanced header (currently unused) 15. `vertical_mushaf_view.dart` - Continuous scroll view

### Architecture Pattern

```
lib/
├── core/quran/              # Reusable Quran components
│   ├── data/                # Pure data (no dependencies)
│   ├── helpers/             # Utility functions
│   └── widgets/             # Reusable UI components
│
└── features/mushaf/         # Mushaf-specific feature
    ├── controller/          # State management
    ├── screens/             # Full page screens
    └── widgets/             # Feature-specific widgets
```

### Key Technologies

- **QCF Fonts:** Quran Complex Fonts for authentic Uthmanic script
- **PageView:** For horizontal page navigation
- **ListView:** For vertical continuous scrolling
- **ChangeNotifier:** For state management
- **GestureDetector:** For verse interaction
- **ModalBottomSheet:** For verse options menu

### Data Flow

1. User interacts with `MushafScreen`
2. `MushafController` manages state
3. View widgets (`HorizontalMushafView` / `VerticalMushafView`) display UI
4. `PageviewQuran` renders pages
5. `_PageContent` builds individual pages
6. `QcfVerse` renders individual verses using data from `quran_text.dart`
7. `HeaderWidget` shows Surah headers using data from `suwar.dart`

---

**Document Created:** 2025-12-01  
**Total Files Documented:** 15  
**Total Lines of Code:** ~59,000  
**Total Size:** ~3.8 MB
