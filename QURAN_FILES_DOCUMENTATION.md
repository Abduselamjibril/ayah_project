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

**Helper Files (1):**
7. `convert_to_arabic_number.dart` - Numeral conversion utility

**Widget Files (3):**
8. `header_widget.dart` - Surah header display
9. `qcf_verse.dart` - Individual verse rendering with QCF fonts
10. `quran_pageview.dart` - Main page view widget (horizontal/vertical)

### Features Mushaf Module
**Purpose:** Implements the Mushaf reading interface with user interactions.

**Controller Files (1):**
11. `mushaf_controller.dart` - State management (bookmarks, navigation, highlighting)

**Screen Files (1):**
12. `mushaf_screen.dart` - Main Mushaf screen with AppBar and navigation

**Widget Files (3):**
13. `horizontal_mushaf_view.dart` - Page-by-page view with controls
14. `mushaf_header.dart` - Enhanced header (currently unused)
15. `vertical_mushaf_view.dart` - Continuous scroll view

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
