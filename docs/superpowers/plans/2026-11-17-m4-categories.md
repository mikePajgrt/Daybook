# Daybook M4: Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Events can carry Daybook's own categories (a name and an SF Symbol), on any calendar including read-only ones. Categories filter every view the way calendars do, show as symbols on events where there is room, and sync between the user's own devices through iCloud once the build is given a CloudKit container. Without one, they live on the device.

**Architecture:** Everything that is not storage or drawing lives in `Packages/DaybookCore`: `Category`, name validation, the curated symbols, `CategoryAssignments` (series and single-occurrence assignments and the lookup rule), `CategorySelection` (what an editor or the detail toggles), `CategoryFilter` combined with `VisibilityFilter`, `CategoryMerge` (moving local data into the synced store), the `CategoryStore` protocol and `InMemoryCategoryStore`. `App/System/` adds `SwiftDataCategoryStore` over CloudKit-compatible SwiftData models and the container factory that decides between CloudKit and local storage. `AppModel` stays the single owner of state and owns a `CategoryModel` (categories, assignments, filter, sync state, the open category editor); `AppModel.reload()` applies the category filter before laying out. New UI under `App/Categories/`, one responsibility per file.

**Tech Stack:** Swift (language mode 5), SwiftUI, SwiftData, CloudKit (account status only), Swift Testing, XcodeGen, Xcode 26, iOS 26, macOS 26.

**Spec:** `docs/superpowers/specs/2026-11-17-daybook-design.md`, sections 2, 3.1, 3.2, 4.2, 4.6, 4.8, 5, 6 and 10. This plan covers build step 4 of section 9.

**Scope notes for M4:**
- A category has an id (UUID), a name, a symbol (SF Symbol name) and an order. No colour: colour belongs to calendars, and the product requires that colour is never the only carrier of meaning.
- Assignments key on `EventKey`. An assignment without an occurrence start applies to the whole series and to a single event whatever its start (so moving a single event keeps its categories). An assignment with an occurrence start applies to that occurrence only and adds to the series' categories. A series category cannot be removed from one occurrence (that would need negative assignments); the UI shows it as inherited and disabled in "jen tato událost".
- Unassigning from the series also removes that category's single-occurrence assignments of the series. Assigning to the series removes the now-redundant occurrence assignments.
- An assignment whose event no longer exists is kept and simply not shown (spec 5). The delete confirmation counts assignments: a series counts as one.
- The filter: a set of switched-off category ids and a switch for "Bez kategorie". An event is shown when at least one of its known categories is on, or when it has none and "Bez kategorie" is on. Everything is on by default, so a new category hides nothing. The filter is remembered per device (`UserDefaults`, key `categoryFilter`).
- Name validation: non-empty after trimming, unique ignoring case and diacritics.
- Sync is off in the default build: there is no team id. The container identifier comes from the Info.plist key `DaybookCloudKitContainer`, set from the build setting `DAYBOOK_CLOUDKIT_CONTAINER`, empty by default. Empty means local storage only. If the CloudKit store fails to open, the app falls back to the local store and says so in the sync line.
- Local data survives turning sync on: the local and the synced store are separate files, and whenever the synced store opens, everything in the local store is moved into it (duplicates by id are skipped) and removed from the local store.
- "Only this occurrence" on a split series: an edit with "this and future events" that starts a new series gives it a new external ID; its categories are not carried over (EventKit gives the new series no link to the old one).
- The event context menu (Mac and iPad, and long press in the iPhone day sheet and grid) offers the categories as toggles; for an occurrence of a recurring event as two submenus, "Celá série" and "Jen tato událost".
- Symbols appear on month rows, span lines, time-grid blocks, the agenda and the day sheet only where the title keeps its full room; VoiceOver labels name the categories.
- Search is M5; it will apply the same filter.

**Conventions:** as in the M1 plan. Run package tests with `swift test --package-path Packages/DaybookCore`. Build with `xcodegen generate`, then `xcodebuild -project Daybook.xcodeproj -scheme Daybook -derivedDataPath .build/xcode -quiet build` with `-destination 'platform=macOS'` and `-destination 'generic/platform=iOS Simulator'`. Work on branch `m4-categories`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `Packages/DaybookCore/Sources/DaybookCore/Model/Category.swift` | `Category`, `CategoryScope`, `CategoryAssignment` |
| `Packages/DaybookCore/Sources/DaybookCore/Model/CategoryAssignments.swift` | Assignment index: assign, unassign, lookup, counts, removal |
| `Packages/DaybookCore/Sources/DaybookCore/Model/CategorySymbols.swift` | The curated SF Symbol names offered for categories |
| `Packages/DaybookCore/Sources/DaybookCore/Edit/CategoryName.swift` | Name validation |
| `Packages/DaybookCore/Sources/DaybookCore/Edit/CategorySelection.swift` | What an editor toggles: series and occurrence sets, the changes to apply |
| `Packages/DaybookCore/Sources/DaybookCore/Filter/CategoryFilter.swift` | Switched-off categories, "Bez kategorie", combined with `VisibilityFilter` |
| `Packages/DaybookCore/Sources/DaybookCore/Store/CategoryStore.swift` | Protocol, `CategoryStoreError`, `CategorySyncState` |
| `Packages/DaybookCore/Sources/DaybookCore/Store/InMemoryCategoryStore.swift` | Test and demo implementation |
| `Packages/DaybookCore/Sources/DaybookCore/Store/CategoryMerge.swift` | Which local records move into the synced store |
| `Packages/DaybookCore/Sources/DaybookCore/Demo/DemoData+Categories.swift` | Five categories and their assignments |
| `Packages/DaybookCore/Tests/DaybookCoreTests/Category*Tests.swift` | One test file per source file above |
| `App/System/CategoryRecords.swift` | SwiftData models `CategoryRecord`, `CategoryAssignmentRecord` |
| `App/System/CategoryContainer.swift` | CloudKit or local container, fallback, moving local data in |
| `App/System/SwiftDataCategoryStore.swift` | `CategoryStore` over SwiftData; account status |
| `App/Categories/CategoryModel.swift` | Observable category state owned by `AppModel` |
| `App/Categories/CategoryEditorModel.swift` | Form state of the create / edit sheet |
| `App/Categories/CategoryEditorView.swift` | Name, symbol grid, sync line |
| `App/Categories/CategorySymbolGrid.swift` | The symbol picker with Czech accessible labels |
| `App/Categories/CategoryText.swift` | Czech wording: symbol names, sync states, counts, errors |
| `App/Categories/CategorySidebarSection.swift` | The sidebar's "Kategorie" section, context menu, delete confirmation |
| `App/Categories/CategoryChecklist.swift` | Scope choice and checkmark rows, shared by the editor page and the detail |
| `App/Categories/EventCategoryMenu.swift` | Category toggles for the event context menu |
| `App/Categories/CategorySymbolsView.swift` | Symbols drawn next to an event title, with a fits-or-drop rule |
| `App/AppModel.swift`, `App/Editor/*`, `App/Month/*`, `App/TimeGrid/*`, `App/Shell/*` | Filter in `reload()`, editor row, detail section, symbols on events |
| `App/DaybookApp.swift`, `App/System/DemoStaging.swift` | Store choice, demo staging |
| `project.yml`, `App/DaybookCloud-iOS.entitlements`, `App/DaybookCloud-macOS.entitlements` | Switchable sync configuration |
| `scripts/capture-review.sh` | Captures of the new states |

---

### Task 1: Categories, names and symbols

**Files:**
- Create: `Model/Category.swift`, `Model/CategorySymbols.swift`, `Edit/CategoryName.swift`
- Test: `CategoryTests.swift`

**Behaviour:** `Category(id:name:symbol:order:)`, `Identifiable`, `Hashable`, `Codable`. `CategoryAssignment(categoryID:externalID:occurrenceStart:)` with `scope` (`.series` when `occurrenceStart` is `nil`). `CategoryName.problems(_:among:excluding:)` returns `.empty` or `.duplicate`; `CategoryName.normalized` trims. `CategorySymbols.offered` is a list of unique SF Symbol names and contains every demo symbol; `CategorySymbols.fallback` is `"tag"`.

- [ ] **Step 1: Write the failing tests:** blank and whitespace names are `.empty`; "porady" and " PORADY " against "Porady" are `.duplicate`; "Zdravi" against "Zdraví" is `.duplicate`; renaming a category to its own name with different case is fine (excluding itself); offered symbols are unique and non-empty.
- [ ] **Step 2: Run.** Expected: build fails, `cannot find 'Category' in scope`.
- [ ] **Step 3: Implement. Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** `Add categories, name validation and the offered symbols`.

### Task 2: Assignments and selection

**Files:**
- Create: `Model/CategoryAssignments.swift`, `Edit/CategorySelection.swift`
- Test: `CategoryAssignmentsTests.swift`

**Behaviour:** as in the scope notes. `categoryIDs(for:)` is the union of the series' and the occurrence's assignments. `remove(category:)` returns how many assignments went. `count(of:)`. `CategorySelection(assignments:key:)` gives `series` and `occurrence` sets; `isOn(_:scope:)`, `isInherited(_:scope:)`, `toggle(_:scope:)`; `changes(from:)` lists `CategoryChange` values (assign or unassign, with scope).

- [ ] **Step 1: Write the failing tests**
  - a series assignment applies to every occurrence; an occurrence assignment only to its own; together they add up
  - a series assignment applies to a single event after its start moved
  - assigning to the series removes the same category's occurrence assignments of that series
  - unassigning from the series removes its occurrence assignments of the same category; other series untouched
  - unassigning an occurrence leaves the series' assignment; assigning twice keeps one
  - removing a category returns its count and leaves the others
  - assignments for events that do not exist are kept (nothing looks them up)
  - selection: toggling in series scope, toggling in occurrence scope, inherited ids cannot be toggled off in occurrence scope, `changes(from:)` produces exactly the differences
- [ ] **Step 2: Run, see them fail. Step 3: implement. Step 4: run, see them pass.**
- [ ] **Step 5: Commit** `Add category assignments for series and single occurrences`.

### Task 3: Category filter

**Files:**
- Create: `Filter/CategoryFilter.swift`
- Test: `CategoryFilterTests.swift`

**Behaviour:** `CategoryFilter(hiddenIDs:showsUncategorized:)`, defaults to everything on; `isVisible(categoryIDs:known:)`; `toggle`, `toggleUncategorized`, `showOnly(_:)` (hides every other category and "Bez kategorie"), `showOnlyUncategorized(among:)`, `showAll()`, `storedValue` round trip. `VisibilityFilter.visibleEvents(_:categories:assignments:known:)` keeps an event when its calendar is on and the category rule holds.

- [ ] **Step 1: Write the failing tests:** everything visible by default; a new category id is visible; one category off hides an event with only that category but not one with another category on; "Bez kategorie" off hides uncategorized events only; unknown (deleted) ids count as no category; show only; show all; stored round trip; combined with a hidden calendar.
- [ ] **Step 2: Run, see them fail. Step 3: implement. Step 4: run, see them pass.**
- [ ] **Step 5: Commit** `Add the category filter`.

### Task 4: Store protocol and in-memory store

**Files:**
- Create: `Store/CategoryStore.swift`, `Store/InMemoryCategoryStore.swift`, `Store/CategoryMerge.swift`
- Test: `InMemoryCategoryStoreTests.swift`, `CategoryMergeTests.swift`

**Behaviour:** protocol: `syncState`, `categories()` sorted by order then name, `assignments()`, `createCategory(name:symbol:)`, `renameCategory(_:to:)`, `setSymbol(_:ofCategory:)`, `reorderCategories(_:)`, `deleteCategory(_:)`, `assign(_:to:scope:)`, `unassign(_:from:scope:)`, `changes`. Errors: `categoryNotFound`, `invalidName([CategoryNameProblem])`, `invalidSymbol`, `system(String)`. Every write emits one change. `CategoryMerge.plan(local:into:)` returns the categories and assignments to insert (existing ids and existing assignments skipped).

- [ ] **Step 1: Write the failing tests:** create appends at the end with a trimmed name; duplicate and empty names throw; rename and symbol change; reorder sets the order of the listed ids and keeps the rest after them; delete removes its assignments and reports `categoryNotFound` for an unknown id; assign to an unknown category throws; each write emits exactly one change; merge skips existing ids and duplicate assignments.
- [ ] **Step 2: Run, see them fail. Step 3: implement. Step 4: run, see them pass.**
- [ ] **Step 5: Commit** `Add the category store protocol and the in-memory store`.

### Task 5: Demo categories

**Files:**
- Create: `Demo/DemoData+Categories.swift`
- Test: `DemoDataTests.swift`

**Behaviour:** five categories with fixed UUIDs: Porady (`person.2`), Soustředěná práce (`brain.head.profile`), Děti (`figure.and.child.holdinghands`), Cestování (`airplane`), Zdraví (`heart`). Assignments by title among the generated events (meetings, focus work, children, health), "Návrh API" with Porady and Soustředěná práce, the weekly series with Porady on the series, its occurrence on the Monday of today's week with Soustředěná práce on that occurrence only, a read-only event ("Odstávka DB") with a category, the trips with Cestování. `DemoData.categoryStore(month:calendar:)`.

- [ ] **Step 1: Write the failing tests:** five categories in order; "Návrh API" has two; some events have none; the series' occurrences all have Porady and only the 16th also has Soustředěná práce; the read-only event has a category; deterministic.
- [ ] **Step 2–4:** fail, implement, pass. **Step 5: Commit** `Add demo categories and assignments`.

### Task 6: SwiftData store and switchable sync

**Files:**
- Create: `App/System/CategoryRecords.swift`, `App/System/CategoryContainer.swift`, `App/System/SwiftDataCategoryStore.swift`, `App/DaybookCloud-iOS.entitlements`, `App/DaybookCloud-macOS.entitlements`
- Modify: `project.yml`

**Behaviour:** models: `CategoryRecord` (`identifier: UUID`, `name: String`, `symbol: String`, `order: Int`, all defaulted) and `CategoryAssignmentRecord` (`categoryID: UUID`, `externalID: String`, `occurrenceStart: Date?`); no unique constraints, no relationships. `CategoryContainer.open(cloudContainerID:)`: no identifier: local store `Categories-local.store`. With one: CloudKit store `Categories-cloud.store` in the private database; if that throws, local store and state `.iCloudUnavailable`. After the CloudKit store opens, the local store's content is moved in (`CategoryMerge`). Account status from `CKContainer.accountStatus()`, refreshed on `CKAccountChanged`: available is `.syncing`, anything else `.iCloudUnavailable`. A local store that cannot open falls back to memory with `.notSaved`. Not unit-testable (SwiftData and CloudKit stay out of the package); verified by both builds; the CloudKit path is not exercised in this milestone (no team).

- [ ] **Step 1: Implement. Step 2:** both builds. **Step 3: Commit** `Store categories in SwiftData with switchable iCloud sync`.

### Task 7: Category model and filter in the app

**Files:**
- Create: `App/Categories/CategoryModel.swift`, `App/Categories/CategoryEditorModel.swift`, `App/Categories/CategoryText.swift`
- Modify: `App/AppModel.swift`, `App/DaybookApp.swift`

**Behaviour:** `AppModel(store:categoryStore:...)` owns `categoryModel`; `reload()` filters loaded events with `VisibilityFilter.visibleEvents` before any layout, so month rows close up and grids re-lay-out. The category change stream reloads both models. Demo mode uses `DemoData.categoryStore`, never the on-disk store.

- [ ] **Step 1: Implement. Step 2:** both builds. **Step 3: Commit** `Add the category model and filter events by category`.

### Task 8: Sidebar, editor, assigning, showing

**Files:**
- Create: the rest of `App/Categories/`
- Modify: `App/Shell/SidebarView.swift`, `App/Editor/EventEditorView.swift`, `App/Editor/EventEditorModel.swift`, `App/Editor/AppModel+Editing.swift`, `App/Editor/EventDetailView.swift`, `App/Editor/EventDetailPresenter.swift`, `App/Month/*`, `App/TimeGrid/EventBlockView.swift`, `App/Shell/AgendaView.swift`

**Behaviour:** sidebar section "Kategorie" under the calendars: checkbox in ink (no colour), symbol, name; "Bez kategorie"; "Nová kategorie"; footer with the sync line. Context menu: Přejmenovat…, Změnit symbol…, Zobrazit jen tuto, Zobrazit všechny, Smazat kategorii… (confirmation names the category and how many events lose it). Drag to reorder (`onMove`). Editor sheet: name, symbol grid (44 pt cells, selected cell filled with ink, Czech accessible labels), sync line. Event editor: "Kategorie" row pushing the checklist; for an occurrence of a recurring event a "Celá série" / "Jen tato událost" choice (series is the default); category-only changes save without the recurring-span question. Detail: "Kategorie" section with symbol and name, "Upravit kategorie" disclosure with the checklist, also for read-only calendars. Context menu on events with the toggles. Symbols on events where there is room; VoiceOver names categories.

- [ ] **Step 1: Implement. Step 2:** both builds. **Step 3: Commit** in small steps.

### Task 9: Staging and captures

**Files:**
- Modify: `App/DaybookApp.swift`, `App/System/DemoStaging.swift`, `scripts/capture-review.sh`

**Behaviour:** `-demo-category-off` (Porady off), `-demo-uncategorized-off`, `-demo-categories` (iPhone: the sheet open on the categories), `-demo-category-editor` (editing Děti), `-demo-category-delete` (asks to delete Porady), `-demo-editor-categories` (event editor on the series' occurrence, categories page open), `-demo-detail-categories` (detail of the read-only "Odstávka DB" with the checklist open), `-demo-icloud-unavailable` (sync line state). Captures for iPhone, iPad and Mac, at least one light and one accessibility-large.

- [ ] **Step 1: Run** `sh scripts/capture-review.sh`, open every new PNG, check: each shows what its name says; symbols legible and never crowding titles; the sidebar sections read clearly; the filter visibly changes the month and rows close up; native controls in the world's colours; Czech copy names its action; nothing clipped at accessibility-large; both appearances legible. At most two rounds, fixes batched.
- [ ] **Step 2: Verify** package tests and both builds, then commit `Capture the category states for review`.

---

## Turning on iCloud sync (for the user)

Sync needs a paid Apple Developer account. Nothing below is needed to build or run the app; until it is done, categories are stored on each device only, and the sidebar says so.

1. **Team:** in `project.yml`, under `targets.Daybook.settings.base`, uncomment `DEVELOPMENT_TEAM` and put your 10-character team id (Xcode, Settings, Accounts, or developer.apple.com, Membership).
2. **Container:** uncomment `DAYBOOK_CLOUDKIT_CONTAINER` and set it to a container id that starts with `iCloud.`, for example `iCloud.app.daybook.Daybook`. Create the same container at developer.apple.com (Certificates, Identifiers & Profiles, iCloud Containers) and assign it to the app id `app.daybook.Daybook` with the iCloud capability (CloudKit) and Push Notifications.
3. **Entitlements:** comment out the two lines marked "unsigned build" (`CODE_SIGN_IDENTITY[sdk=macosx*]: "-"` and the current `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`) and uncomment the two `CODE_SIGN_ENTITLEMENTS[sdk=...]` lines that point to `App/DaybookCloud-iOS.entitlements` and `App/DaybookCloud-macOS.entitlements`. Those files read the container id from the build setting, so they need no editing.
4. **Background pushes on iOS:** uncomment `UIBackgroundModes: [remote-notification]` under the target's `info.properties`, so changes from the other device arrive while the app is in the background.

Then run `xcodegen generate` and build with signing. On first launch with sync on, categories made before are moved from the local store into the synced one. Before shipping, deploy the CloudKit schema from the development to the production environment in the CloudKit console.
