# Quran App UI Documentation

## Overview
This documentation serves as a guide for UI developers working on the Quran App. The application is built using Flutter and follows a feature-first architecture with a strong emphasis on theming and high-quality "glassmorphic" design elements.

## 1. Project Structure (UI Focus)

### Core UI (`lib/core/ui`)
Contains shared, reusable UI components that define the app's aesthetic.
- **`modern_app_bar.dart`**: A customizable, floating glassmorphic app bar. Used throughout the app to maintain a premium feel.
- **`glassmorphic_card.dart`**: A wrapper widget providing the frosted glass effect used in lists and dialogs.
- **`premium_button.dart`**: Styled buttons with gradients and shadows.
- **`loading_indicator.dart`**: Custom loading animations.

### Theming (`lib/core/services/theme_service.dart`)
The app supports 4 distinct themes, managed by `ThemeService`. This service handles switching `ThemeData` and associated assets (background images).

**Defined Themes (`AppTheme` enum):**
1. **Golden Parchment** (`light`): Default. Beige/Gold tones. 
   - *Assets*: `mainframe.png`, `Page.png`
2. **Midnight Blueprint** (`dark`): Deep blue/night tones.
   - *Assets*: `mainframe_dark.png`, `Page_dark.png`
3. **Mint Garden** (`light`): Green/Nature tones.
   - *Assets*: `green_mainframe.png`, `Page_green.png`
4. **Ornate Twilight** (`dark`): Dark green/grey tones.
   - *Assets*: `green_mainframe_dark.png`, `Page_green_dark.png`

**Colors (`lib/core/constants/app_colors.dart`):**
All color definitions are centralized here. Use these constants instead of hardcoded colors.
- `lightAccent`, `darkAccent`, etc. define the primary brand colors for each theme.

## 2. Mushaf (Quran) Implementation

The core reading experience is located in `lib/features/mushaf`.

### Main Screen (`mushaf_screen.dart`)
- **`MushafScreen`**: The entry point for reading. It orchestrates the view using `MushafController`.
- **View Modes**: Switches between `HorizontalMushafView` (paged) and `VerticalMushafView` (scrollable) based on user preference.
- **Floating Controls**: Implements a custom disappearing top bar and search overlay.

### Rendering Engine (`lib/core/quran/widgets/quran_pageview.dart`)
This is the most critical UI component. It renders the actual Quran pages.

- **`PageviewQuran`**: A widget that handles the swipe/scroll mechanics.
- **`QuranPageContent`**: Responsible for laying out verses.
  - **Fonts**: Uses QCF v1/v2 fonts (e.g., `QCF_P001.ttf`). Each page has a specific font file to ensure exact "Madani" script layout.
  - **Verse Highlighting**: `verseBackgroundColor` callback allows coloring specific verses (used for bookmarks/playback interactively).
  - **Interactions**: Handles long-press gestures for audio/bookmark options context menu.

## 3. Key Development Guidelines

1. **Assets**: 
   - Put images in `assets/images/`.
   - Ensure you provide variants for all 4 themes if adding a new themed asset (e.g. backgrounds).

2. **Typography**:
   - Use `Theme.of(context).textTheme` styles.
   - For Quran text, **always** use the specialized font logic in `quran_pageview.dart`. Do not try to render Quran text with standard fonts as it will break the fixed-page layout.

3. **Responsiveness**:
   - The app uses custom scaling factors (`sp`, `h`) passed down to widgets. Ensure UI elements adapt to different screen sizes, especially for the Mushaf view.

4. **Glassmorphism**:
   - Use `ModernFloatingAppBar` or `GlassmorphicCard` containers for overlays to maintain design consistency.
   - Avoid solid opaque backgrounds for floating elements.

## 4. Common Tasks for New Developers

- **Adding a new Theme**: 
  1. Add entry to `AppTheme` enum in `theme_service.dart`.
  2. Define colors in `app_colors.dart`.
  3. Create `ThemeData` getter in `ThemeService`.
  4. Add corresponding assets (mainframe, page bg).

- **Modifying Quran Layout**:
  - Edit `QuranPageContent` in `quran_pageview.dart`.
  - **Caution**: Changing font sizes or line heights indiscriminately will break the page boundaries. Test on multiple pages (dense vs sparse text).

- **New Feature Screen**:
  - Create directory in `lib/features/<feature_name>`.
  - Use `Scaffold` with `ModernFloatingAppBar` for consistency.
