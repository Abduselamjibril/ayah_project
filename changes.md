# Changes Log

This file tracks client-facing improvements and notable technical changes, grouped by topic/category.

## 2026-02-04

### UI/UX — Downloads AppBar Back Label Wrapping

- **Goal:** Prevent the back label (“Settings”) from wrapping into two lines on the Downloads screen app bar.
- **Before:** `TextButton.icon` leading label could wrap on smaller widths, producing an unpolished header layout.
- **After:** Leading label is constrained to a single line with ellipsis, and leading width is increased slightly.
- **How:** Set `maxLines: 1`, `overflow: TextOverflow.ellipsis`, `softWrap: false`, and adjusted `leadingWidth`.
- **Files:** `quran_app/lib/features/downloads/downloads_screen.dart`

### UI/UX — Active/Current Ayah Highlight (Audio + Long-Press)

- **Goal:** Make the “currently active” ayah highlight (audio-follow + long-press) look modern (rounded corners), while keeping verse positioning stable.
- **Before:** Highlight was drawn using `TextSpan` background color, which produces rigid, sharp-edged rectangles and offers no true corner radius.
- **After:** Highlight is rendered as rounded rectangles behind the text using the actual layout boxes from `RenderParagraph`, with tuned padding so it hugs the script (no excessive vertical bleed).
- **How:**
  - Replaced `TextSpan(backgroundColor: …)` highlight with a `CustomPaint` layer that draws `RRect`s using `RenderParagraph.getBoxesForSelection(...)`.
  - Added a vertical “tighten” step (reduces highlight box height) to compensate for the mushaf’s larger line-height.
  - Tuned padding values to avoid overlaps while retaining a consistent visual style.
- **Files:** `quran_app/lib/core/quran/widgets/quran_pageview.dart`

### UI/UX — Vertical Mushaf Page Slider: Reduce Accidental Drag Hitbox

- **Goal:** Prevent accidental page slider dragging when tapping near the vertical slider (only the visible slider should be draggable).
- **Before:** The slider `GestureDetector` wrapped a wide container (bar width + extra space for the tooltip), so taps well outside the bar could start a drag.
- **After:** Only the bar area is draggable; the tooltip still appears while sliding but no longer expands the interactive hit area. While dragging, the number on the draggable pill is hidden to avoid redundant page number display.
- **How:** Separated the bar drag `GestureDetector` (bar-width only) from the tooltip, and wrapped the tooltip in `IgnorePointer`.
- **Files:** `quran_app/lib/features/mushaf/widgets/vertical_mushaf_view.dart`

### UI/UX — Mushaf Drawer Tabs: Prevent Label Wrapping

- **Goal:** Prevent segmented tabs (e.g., “Contents”) from wrapping into a second line in the mushaf drawer app bar.
- **Before:** Toggle width could be too narrow on some devices, causing the last character(s) to wrap (e.g., `Content` + `s`).
- **After:** Toggle width is increased so labels fit on one line without wrapping.
- **How:** Increased the app bar segmented control `toggleWidth` (`180` → `195`) to give the tab labels more horizontal space.
- **Files:** `quran_app/lib/features/mushaf/widgets/surah_drawer.dart`

### Stability — Fix Missing Asset Directory Blocking Builds/Tests

- **Goal:** Remove a missing asset entry that was breaking `flutter test` and analyzer runs.
- **Before:** `pubspec.yaml` referenced `assets/flags/`, but the directory didn’t exist, causing tool failures.
- **After:** Removed the nonexistent asset entry so builds/tests can run.
- **Files:** `quran_app/pubspec.yaml`

### Quality — Replace Template Widget Test With App-Relevant Tests

- **Goal:** Restore a green test signal with a test that matches the actual app (not the default counter template).
- **Before:** Default template test expected a counter UI that doesn’t exist in this project.
- **After:** Added small sanity tests for Quran core invariants (page/surah counts and basic lookups).
- **Files:** `quran_app/test/widget_test.dart`

### Documentation — Add Technical Audit Baseline

- **Goal:** Establish an initial audit and upgrade plan baseline to guide UI/UX, performance, and architecture work.
- **What:** Added an audit document covering structure, dependencies, analysis results, and prioritized risks.
- **Files:** `quran_app/docs/upgrade_audit.md`

### UI/UX — App Theme: Surah Header Style Selector Redesign

- **Goal:** Make the “Surah Header Style” selector feel modern and minimalist (closer to the reference), while taking less vertical space.
- **Before:** Two large style cards with prominent labels and a heavy fade/overlay treatment; it felt oversized and visually dated.
- **After:** A compact 2-row selector with small previews, reduced row height, and a clear selected state (check icon + subtle background tint), without the large fade effect.
- **How:** Replaced the old card UI with `_buildSurahHeaderStyleSelector(...)`, then tuned row/preview sizing to remove excess vertical padding while keeping the preview readable.
- **Files:** `quran_app/lib/features/settings/theme_settings_page.dart`
