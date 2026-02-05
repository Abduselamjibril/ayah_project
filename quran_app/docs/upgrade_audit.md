# Ayah Project (Flutter) — Audit & Upgrade Notes

Date: 2026-02-04

This document is a quick technical/UX audit of the current `quran_app` codebase to help plan UI/UX, logic, and performance upgrades.

## Tooling Snapshot

- Flutter: `3.38.0` (via FVM)
- State management: `provider` + `ChangeNotifier` + `ValueNotifier`
- Storage: `sqflite` (SQLite) + `SharedPreferences`
- Networking: `http`
- Background: `workmanager`, `home_widget`, `flutter_downloader`
- Audio: `audio_service` + `just_audio`

## Current App Entry Points

- Bootstrap: `quran_app/lib/main.dart`
  - Initializes: database, theme, language, mushaf settings, notifications, verse-of-the-day, home-widget sync, wakelock.
  - Providers: `BookmarkNotesNotifier`, `HighlightNotifier`
- Navigation: `quran_app/lib/app/router.dart` (simple `onGenerateRoute`)
- Core reading UI: `quran_app/lib/features/mushaf/screens/mushaf_screen.dart`

## Architecture (High-Level)

**Reading (Mushaf)**
- Uses bundled QCF data/fonts via `quran_app/lib/core/quran/qcf_quran.dart`.
- `MushafController` manages page/scroll mode/highlight and emits navigation events.
- `PageviewQuran` renders pages (horizontal via `PageView`, vertical via `ScrollablePositionedList`).

**Bookmarks / Notes**
- UI state: `BookmarkNotesNotifier` (Provider).
- Persistence: SQLite tables `bookmarks` and `notes` via `BookmarkNotesRepository`.
- Home widget: `HomeWidgetService` syncs “last read” (Android periodic work).

**Highlights**
- UI state: `HighlightNotifier` (Provider).
- Persistence: (appears to be local storage; review `HighlightRepository` for format/limits).

**Search**
- UI: `quran_app/lib/features/search/search_screen.dart`
- Repository: `SearchRepository` queries local FTS tables (`ayahs_fts`, `translations_fts`) and also supports “jump” queries (e.g., `2:255`, surah name).

**Downloads**
- Screen: `quran_app/lib/features/downloads/downloads_screen.dart`
- Services:
  - `TranslationService` + `TranslationApi`: downloads translations (114 API calls; one per surah), stores in SQLite.
  - `TafsirService` + `TafsirApi`: similar approach for tafsir.
  - `AudioService` + `AudioApi`: downloads a chapter audio file + verse segments, stores to app support dir.

**Notifications**
- `AppNotificationService` schedules daily verse + shows download progress notifications.
- `VerseOfTheDayService` controls daily verse generation and scheduling.

## Static Analysis & Test Status

I ran `fvm flutter analyze --no-pub` and `fvm flutter test --no-pub`.

- Analyzer: **549 issues** total (**57 warnings**, **492 infos**, **0 errors**).
  - Largest buckets (by message match):
    - `withOpacity` deprecation: **279**
    - `print` in production: **114**
    - `BuildContext` across async gaps: **30**
    - “use const”: **25**
- Tests: now **passing** (replaced the default template counter test with lightweight core-data tests).

## Notes / Risks to Track (Before UI Refresh)

### P0 (Blockers / High Risk)

- **Search data population**: the SQLite `ayahs` table is created, and FTS tables exist, but there’s no clear “seed arabic ayahs into DB” step in code. That likely means:
  - Arabic search (and suggestions) returns empty on fresh installs.
  - Plan: either ship a prebuilt DB asset or seed `ayahs` from `core/quran/data/quran_text.dart` on first run (batch insert + FTS sync).
- **Permission UX**: `main.dart` requests notification permissions immediately at startup. This is usually a UX anti-pattern; request only when the user enables reminders/features.
- **Always-on wakelock**: `WakelockPlus.enable()` is called unconditionally. This should be user-configurable (and ideally only enabled for specific reading/audio modes).

### P1 (Quality / Maintainability)

- **Logging**: many `print(...)` calls across services/apis/DAOs. Replace with a centralized logger (and keep release builds quiet).
- **Deprecated color API**: `Color.withOpacity` is deprecated in this Flutter/Dart version; migrate to `withValues(...)` (or equivalent) across the codebase.
- **Async context usage**: multiple `use_build_context_synchronously` lints; fix with `if (!mounted) return;` and avoid using `context` after awaits.
- **Dead/placeholder files** (0 bytes): there are several empty files (repositories/services/constants/dao). Decide whether to delete them or implement them to avoid confusion.
- **Localization gaps**: the app uses a custom JSON i18n system (`AppLocalizations`) but many UI strings are still hard-coded (English). Plan a consistent i18n approach.

### P2 (Performance / Product Polish)

- **Startup cost**: a lot of initialization happens synchronously before `runApp`. Consider a lightweight splash + async init, and defer non-critical work.
- **Download strategy**: translation/tafsir download uses 114 sequential requests. Consider controlled parallelism + caching + better progress and failure recovery.
- **Theme consistency**: `BrandColors.accent` is used in many places, sometimes ignoring the current `ThemeData` color scheme. Consider consolidating brand styling into the theme.

## Suggested Upgrade Plan (Practical Order)

1. **Stabilize foundations (P0)**: seed/ship Arabic DB + fix permission/wakelock behavior.
2. **Code health (P1)**: remove prints, fix async context, migrate away from deprecated APIs, delete/implement placeholder files.
3. **UI/UX refresh (P1/P2)**: unify design tokens (colors/typography/spacing), audit navigation patterns and bottom sheets, fix localization coverage.
4. **Performance pass (P2)**: startup deferrals, reduce unnecessary rebuilds, measure mushaf rendering + scrolling jank, optimize downloads.
5. **Dependency upgrades**: update packages in controlled steps and fix breaking changes; keep a clean CI signal with `flutter analyze` + tests.

## Commands (Local Dev)

- `cd quran_app`
- `fvm flutter pub get`
- `fvm flutter analyze --no-pub`
- `fvm flutter test --no-pub`

