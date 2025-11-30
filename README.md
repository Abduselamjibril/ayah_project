# Ayah Project - Quran App

A comprehensive Quran application built with Flutter, featuring high-quality Mushaf rendering, audio playback, and various study tools.

## Getting Started

This project uses FVM (Flutter Version Management) to ensure consistent Flutter versions.

**FVM Version:** `3.38.0`

To run the project:
```bash
fvm flutter pub get
fvm flutter run
```

## Project Structure

The project follows a feature-based architecture:

- **`lib/features/`**: Contains the main feature modules.
  - **`mushaf/`**: The core Quran reading experience.
  - **`audio_player/`**: Audio playback functionality.
  - **`bookmarks/`**: Management of bookmarked verses.
  - **`downloads/`**: Handling downloads for offline access.
  - **`search/`**: Quran search capabilities.
  - **`settings/`**: Application settings.
  - **`tafsir/`**: Tafsir (exegesis) viewing.
- **`lib/core/`**: Core utilities and shared widgets (e.g., `QuranPageview`).
- **`lib/data/`**: Data layer and repositories.

## Key Features

### 📖 Mushaf Screen
The heart of the application is the `MushafScreen` (`lib/features/mushaf/screens/mushaf_screen.dart`), which provides a rich reading experience.

#### **View Modes**
The Mushaf supports two distinct scrolling modes, managed by the `MushafController`:

1.  **Horizontal Mode (`HorizontalMushafView`)**:
    - Simulates a traditional physical Mushaf.
    - Pages are swiped horizontally.
    - Includes navigation buttons (Previous/Next) and a page indicator.
    - Ideal for focused reading and memorization.

2.  **Vertical Mode (`VerticalMushafView`)**:
    - Provides a continuous vertical scrolling experience.
    - Uses a `PageviewQuran` with `ScrollMode.vertical`.
    - Includes a "Scroll to Top" floating action button for easy navigation.
    - Better suited for quick reading or reviewing long passages.

#### **Interactions**
- **Verse Options**: Tapping or long-pressing a verse opens a modal with options:
    - **Bookmark**: Add/Remove bookmarks.
    - **Play Audio**: Listen to the verse recitation.
    - **View Tafsir**: Read the explanation of the verse.
    - **Share**: Share the verse text.
    - **Copy**: Copy verse text to clipboard.
- **Highlighting**: Verses are highlighted when selected or bookmarked.
- **Navigation**:
    - **Jump to Surah**: A menu in the AppBar allows quick navigation to any Surah.
    - **Bookmarks**: A badge in the AppBar shows active bookmarks and allows quick access to them.

#### **Technical Implementation**
- **Rendering**: The app uses QCF (Quran Complex Fonts) for high-quality, scalable rendering of Quran pages.
- **State Management**: `MushafController` handles the logic for:
    - Toggling scroll modes.
    - Tracking current page and Surah.
    - Managing bookmarks (`surah:verse` keys).
    - Handling verse highlighting.

### 🎧 Audio Player
(`lib/features/audio_player/`)
Integrated audio player for listening to Quran recitations.

### 🔖 Bookmarks
(`lib/features/bookmarks/`)
A dedicated screen to view and manage all saved bookmarks.

### 🔍 Search
(`lib/features/search/`)
Search functionality to find specific verses or topics within the Quran.

### 📚 Tafsir
(`lib/features/tafsir/`)
Access to detailed Tafsir (exegesis) for deeper understanding of verses.

### ⚙️ Settings
(`lib/features/settings/`)
Customization options for the app experience.

## Assets
The project relies on a comprehensive set of assets defined in `pubspec.yaml`, including:
- **QCF Fonts**: Individual font files for all 604 pages of the Mushaf to ensure perfect rendering.
- **Icons & Images**: UI assets.
