# Daybook M5: Search and Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any event, past or future, is reachable by search. The month continues into its neighbours when scrolled. Everything still owed from earlier milestones is paid: the signature motion, the toolbar order, line colours that read on porcelain, no system blue, one calendar mark, a clock that rolls over at midnight, categories that survive a split series, a tested SwiftData store. Then first run, states, English, accessibility and an app icon.

**Architecture:** As before, logic lives in `Packages/DaybookCore` and is tested there: `EventSearch` (matching, highlight ranges, grouping, the ten-year range in EventKit-sized chunks), `Palette.lineColor` (a calendar colour adjusted in OKLab lightness to 3:1 on a ground), `MonthLayout` over a run of months, `CategoryAssignments.carriedOver` for a split series, and a `CalendarStore.reader()` that returns a `Sendable` read function so loading and searching run off the main thread. The app gains `App/Search/`, a search model owned by `AppModel`, contrast-aware theme tokens, a clock that follows day changes, and an asynchronous event cache in `AppModel` (the grid draws at once, events fill in; calendar and category toggles re-filter the cache synchronously so the rows can animate). A macOS unit-test target runs `SwiftDataCategoryStore` against in-memory containers.

**Tech Stack:** Swift (language mode 5), SwiftUI, SwiftData, Swift Testing, XcodeGen, Xcode 26, iOS 26, macOS 26, String Catalogs.

**Spec:** `docs/superpowers/specs/2026-11-17-daybook-design.md`, sections 4.1, 4.3, 4.5, 4.9, 5, 6, 7 and 9. This plan covers build step 5 of section 9.

**Scope notes for M5:**
- Search matches every whitespace-separated word of the query, each in any of title, location, notes, attendee names and e-mails, ignoring case and diacritics. Results are grouped by the day the event starts: today and later days ascending first, then earlier days descending. Never capped.
- The search range is five years back and five forward from today, read in chunks of at most four calendar years (EventKit shortens longer predicates). Chunks are built with calendar arithmetic, so clock changes cannot shift them; events that cross a chunk edge are de-duplicated by key.
- The corpus is read once per search session off the main thread and dropped when the calendar database changes. Typing is debounced (250 ms) and a newer query cancels the older one.
- Search respects switched-off calendars and categories; the toggle "Hledat i ve vypnutých" includes them. Choosing a result opens the day view on that day (all platforms: the iPhone already has a day view, which is more consistent than a sheet from search) and opens the event's detail there; an event hidden by the filter opens its detail as a sheet instead.
- Month scrolling ships as a **bounded window**: seven months (the focused one and three either side) in one continuous column of weeks. The title follows the month that owns most of the viewport; days outside that month take outside ink. Back, Today and forward step from the month on screen and re-centre the window. Week heights are computed once per re-centre (the focused month fills the viewport the way it did before), so scrolling never changes a height and never loses position. Scrolling past the window's edge stops there; the next back or forward re-centres.
- Motion: switching a calendar or category on or off animates the re-layout with the system's default spring; under Reduce Motion the month's content crossfades instead. The mode switch crossfades with the system default animation; the custom 0.2 s ease-in-out goes.
- Toolbar on regular width: back / Today / forward, the switcher, search, then "Událost" with a plus as the far-right primary action. On iPhone the bottom bar holds the switcher, search and an icon-only new-event button that keeps its label for VoiceOver.
- Line colours: `Palette.lineColor(_:on:minimumContrast:)` moves only OKLab lightness (hue kept; chroma reduced only to stay in gamut) until the colour holds 3:1 on the ground; compliant colours are returned unchanged. Under Increased Contrast the target is 4.5:1. Used for every line, ring, span, swatch, checkbox and block fill.
- Increased Contrast also steps up rule (16% to 32%), secondary ink (62% to 80%) and block secondary ink (80% to 90%); outside ink already becomes ink at 85%.
- Today rolls over on `NSCalendarDayChanged`, on the significant-time-change and clock-change notifications, and whenever the app becomes active.
- A split series ("this and future" on a later occurrence) returns the new series' key from `updateEvent`; the app copies the old series' categories to it, and occurrence categories from the split onward to the same starts in the new series.
- Localisation: Czech stays the development language; English comes from `Localizable.xcstrings` and `InfoPlist.xcstrings`, with Czech one/few/other plurals. `-demo-locale en` forces English for captures (volatile, never written to disk).
- Release builds contain no demo code: everything demo is `#if DEBUG` (the core's `DemoData` is compiled but never called).

**Conventions:** as in the M1 plan. Package tests: `swift test --package-path Packages/DaybookCore`. App tests: `xcodebuild test -project Daybook.xcodeproj -scheme Daybook -destination 'platform=macOS' -derivedDataPath .build/xcode`. Builds: `xcodegen generate`, then `xcodebuild -project Daybook.xcodeproj -scheme Daybook -derivedDataPath .build/xcode -quiet build` for `platform=macOS` and `generic/platform=iOS Simulator`, Debug and Release. Branch `m5-search-polish`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `Packages/DaybookCore/Sources/DaybookCore/Search/EventSearch.swift` | Query terms, matching, highlight ranges, grouping by day, search range and chunks |
| `Packages/DaybookCore/Sources/DaybookCore/Model/Palette.swift` | `lineColor(_:on:minimumContrast:)` |
| `Packages/DaybookCore/Sources/DaybookCore/Layout/MonthLayout.swift` | Weeks and layout over a run of months; the month a week belongs to |
| `Packages/DaybookCore/Sources/DaybookCore/Model/CategoryAssignments.swift` | `carriedOver(from:to:splitAt:)` |
| `Packages/DaybookCore/Sources/DaybookCore/Store/CalendarStore.swift` | `updateEvent` returns the event's key; `reader()` for reads off the main thread |
| `Packages/DaybookCore/Sources/DaybookCore/Store/InMemoryCalendarStore.swift` | Both of the above |
| `Packages/DaybookCore/Sources/DaybookCore/Demo/DemoData.swift` | Neighbouring months and past events for scrolling and search |
| `Packages/DaybookCore/Tests/DaybookCoreTests/EventSearchTests.swift`, `LineColorTests.swift`, `MonthWindowTests.swift`, `SplitSeriesTests.swift` | Tests |
| `App/Search/SearchModel.swift` | Query, debounce, corpus loading, results |
| `App/Search/SearchResultsView.swift` | Results grouped by day, empty states, the "Hledat i ve vypnutých" toggle |
| `App/Search/SearchResultRow.swift` | Station mark, emphasised title, date and time, calendar, category symbols |
| `App/AppModel.swift` | Event cache filled off the main thread, month window, clock, animated filter changes |
| `App/Month/MonthView.swift`, `WeekRowView.swift` | Continuous window of weeks, title following the scroll, crossfade under Reduce Motion |
| `App/Shell/RootView.swift`, `ViewCommands.swift` | Toolbar order, search, menu commands with shortcuts, empty state without accounts |
| `App/Theme/Theme.swift` | Contrast-aware tokens, line colours, motion |
| `App/Onboarding/AccessView.swift` | First-run copy, ink button |
| `App/Month/DayListView.swift`, `App/Editor/EventDetailView.swift` | Station mark instead of a capsule |
| `App/System/EventKitCalendarStore.swift` | Reader, new key after a split |
| `App/System/CategoryContainer.swift` | Moving device-only data in, testable on two containers |
| `App/Localizable.xcstrings`, `App/InfoPlist.xcstrings` | Czech and English |
| `App/Assets.xcassets` | App icon |
| `scripts/make-app-icon.swift` | Draws the icon with CoreGraphics |
| `AppTests/SwiftDataCategoryStoreTests.swift` | The SwiftData store on in-memory containers |
| `project.yml` | Test target, string catalogs, asset catalog |
| `scripts/capture-review.sh` | Captures of the new states |

---

### Task 1: EventSearch

**Files:** Create `Search/EventSearch.swift`; Test `EventSearchTests.swift`.

**Behaviour:** `EventSearch.terms(_:)` folds case and diacritics and splits on whitespace. `matches(_:terms:)` needs every term in some field. `highlights(in:query:)` returns ranges of the original string. `results(_:query:today:calendar:)` returns `[SearchDay]` (`day`, `events`), de-duplicated by key. `range(around:calendar:years:)` and `chunks(of:maxYears:calendar:)`.

- [ ] **Step 1: Write the failing tests:** "schuzka" finds "Schůzka"; "VLTAVA" finds the location; notes; attendee name and e-mail; two words in two fields match, a word missing anywhere fails; empty and whitespace queries give nothing; upcoming days ascending then past days descending with today first; an event returned twice is kept once; highlights in "Schůzka týmu" for "schuz" cover "Schůz"; the ten-year range over 2026 splits into 4 + 4 + 2 years, contiguous, each at most four calendar years, and the edges sit at local midnight across DST.
- [ ] **Step 2: Run, see them fail. Step 3: implement. Step 4: run, see them pass.**
- [ ] **Step 5: Commit** `Add event search matching, grouping and range chunks`.

### Task 2: Line colours

**Files:** Modify `Model/Palette.swift`; Test `LineColorTests.swift`.

- [ ] **Step 1: Failing tests:** every preset is returned unchanged on both grounds; "Státní svátky" (0.73, 0.75, 0.83) reaches 3:1 on porcelain with its hue within 2°; a dark navy reaches 3:1 on midnight; a 4.5 target is met; greys stay grey.
- [ ] **Steps 2–5:** fail, implement, pass, commit `Adjust calendar line lightness to hold 3:1 on the ground`.

### Task 3: Month window

**Files:** Modify `Layout/MonthLayout.swift`; Test `MonthWindowTests.swift`.

**Behaviour:** `MonthLayout.weeks(from:through:calendar:)` gives the de-duplicated weeks covering a run of months; `layout(weeks:month:events:calendar:)`; `owner(of:calendar:)` is the month holding the week's middle day; `window(around:radius:calendar:)` is the interval of a seven-month window.

- [ ] **Steps 1–5:** tests for de-duplication across a month edge, ordering, DST weeks, ownership; commit `Lay out a run of months as one column of weeks`.

### Task 4: Split series and the store reader

**Files:** Modify `CategoryAssignments.swift`, `CalendarStore.swift`, `InMemoryCalendarStore.swift`; Test `SplitSeriesTests.swift`, `InMemoryWriteTests.swift`.

- [ ] **Steps 1–5:** tests: carried-over assignments copy series categories and later occurrence categories only; the in-memory store returns a new external ID for a split and the old one otherwise; the reader returns the same events as `events(in:calendarIDs:)` and keeps returning them after the store changes. Commit `Carry categories over to a split series and read events off the main thread`.

### Task 5: Demo months

- [ ] Neighbouring months (three each side) and their categories, keyed apart from the central month; the central month's output unchanged (existing tests pass). Commit `Give the demo neighbouring months`.

### Task 6: App test target

- [ ] `AppTests` (macOS unit-test bundle, no host, ad-hoc signed) compiling `CategoryRecords.swift`, `SwiftDataCategoryStore.swift`, `CategoryContainer.swift`. Tests: create, rename, symbol, reorder, delete with assignments, series and occurrence assignment, lookup, change stream, duplicates by id from a sync race, moving device-only data into a synced container. Run, fix what fails, commit `Test the SwiftData category store`.

### Task 7: Theme, motion, marks, blue, clock

- [ ] Contrast-aware tokens and `Theme.line`; line colours everywhere; station mark in the day sheet and detail; ink buttons; the default spring on filter changes with a crossfade under Reduce Motion; the system crossfade for the mode switch; the clock. Commit in steps.

### Task 8: Event cache, month window, toolbar, commands

- [ ] `AppModel` loads through `reader()` off the main thread, draws the grid at once, re-filters synchronously on toggles. The month view becomes the window. Toolbar order and menu commands. Commit in steps.

### Task 9: Search UI

- [ ] `.searchable` with the search item placed in the toolbar order, ⌘F, results, empty states, toggle, choosing a result. Commit `Search events from the toolbar`.

### Task 10: First run, empty state, split-series categories in the app

- [ ] Access copy, no-accounts state, `-demo-first-run`, `-demo-no-accounts`. Commit.

### Task 11: Localisation

- [ ] Every user-facing string through `LocalizedStringKey` or `String(localized:)`; catalogs with English and plurals; `-demo-locale`. Commit `Add English`.

### Task 12: Accessibility pass

- [ ] Day groups with date and count; events with time, title, calendar and categories; values and traits; 44 pt targets on iOS; reading order; Dynamic Type in search, sidebar, editor, detail. Commit.

### Task 13: App icon

- [ ] `scripts/make-app-icon.swift` draws midnight ground, three lines with white stations and an interchange circle into `App/Assets.xcassets/AppIcon.appiconset` (iOS 1024 and the macOS sizes). Commit `Add the app icon`.

### Task 14: Captures and verification

- [ ] New staging arguments: `-demo-search` (query "porada"), `-demo-search-empty`, `-demo-search-none`, `-demo-scrolled` (month scrolled across the November/December edge), `-demo-first-run`, `-demo-no-accounts`, `-demo-locale en`. Captures for iPhone, iPad and Mac, including increased contrast and English main screens. Inspect, at most two rounds. Verify package tests, app tests, Debug and Release builds for both platforms. Commit `Capture the milestone 5 states for review`.
