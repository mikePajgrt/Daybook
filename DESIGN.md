---
name: Daybook
description: A calendar for iOS and macOS that draws every event as a station on its calendar's line.
colors:
  midnight: "#0e1a3a"
  porcelain: "#f4f1ea"
  rail-dark: "#0a1430"
  rail-light: "#eae6dd"
  station-light: "#ffffff"
  outside-ink-dark: "#8f97ad"
  outside-ink-light: "#5b6278"
  outside-ink-dark-ic: "rgba(244, 241, 234, 0.85)"
  outside-ink-light-ic: "rgba(14, 26, 58, 0.85)"
  secondary-ink-dark: "rgba(244, 241, 234, 0.62)"
  secondary-ink-light: "rgba(14, 26, 58, 0.62)"
  secondary-ink-dark-ic: "rgba(244, 241, 234, 0.8)"
  secondary-ink-light-ic: "rgba(14, 26, 58, 0.8)"
  block-secondary-ink-dark: "rgba(244, 241, 234, 0.8)"
  block-secondary-ink-light: "rgba(14, 26, 58, 0.8)"
  block-secondary-ink-dark-ic: "rgba(244, 241, 234, 0.9)"
  block-secondary-ink-light-ic: "rgba(14, 26, 58, 0.9)"
  rule-dark: "rgba(244, 241, 234, 0.16)"
  rule-light: "rgba(14, 26, 58, 0.16)"
  rule-dark-ic: "rgba(244, 241, 234, 0.32)"
  rule-light-ic: "rgba(14, 26, 58, 0.32)"
  weekend-dark: "rgba(0, 0, 0, 0.18)"
  weekend-light: "rgba(14, 26, 58, 0.05)"
  switch-on-dark: "#8d909b"
  switch-on-light: "#0e1a3a"
  line-fallback: "#8f8f94"
  line-preset-red: "#ed4545"
  line-preset-orange: "#db660d"
  line-preset-amber: "#b88000"
  line-preset-green: "#1f9959"
  line-preset-teal: "#00999e"
  line-preset-blue: "#3b82ff"
  line-preset-violet: "#a85ced"
  line-preset-pink: "#e84d99"
typography:
  period-title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 700
  bar-title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 700
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
  day-number:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    fontFeature: "tnum"
  detail:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
  event-row:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    fontFeature: "tnum"
  label:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 600
  micro:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  line-end: "4px"
  block: "4px"
  symbol-cell: "8px"
  mark-tile: "17px"
  full: "9999px"
spacing:
  hairline: "1px"
  block-gap: "2px"
  cell-inset-compact: "3px"
  cell-inset: "6px"
  row-inset: "8px"
  panel: "12px"
  popover: "16px"
  sheet: "20px"
  gate: "32px"
  target: "44px"
components:
  station-mark:
    backgroundColor: "{colors.porcelain}"
    size: "7px"
    width: "3px"
  event-row:
    textColor: "{colors.porcelain}"
    typography: "{typography.event-row}"
    height: "17px"
    padding: "0 0 0 8px"
  span-line:
    textColor: "{colors.porcelain}"
    rounded: "{rounded.line-end}"
    height: "8px"
  interchange-circle:
    backgroundColor: "{colors.porcelain}"
    textColor: "{colors.midnight}"
    typography: "{typography.day-number}"
    rounded: "{rounded.full}"
    size: "22px"
  event-block:
    textColor: "{colors.porcelain}"
    typography: "{typography.label}"
    rounded: "{rounded.block}"
    padding: "2px 3px 2px 5px"
  now-line:
    backgroundColor: "{colors.porcelain}"
    height: "2px"
    size: "11px"
  rail:
    backgroundColor: "{colors.rail-dark}"
    textColor: "{colors.porcelain}"
    width: "248px"
  row-menu-button:
    textColor: "{colors.secondary-ink-dark}"
    width: "32px"
    height: "44px"
  add-row:
    textColor: "{colors.porcelain}"
    typography: "{typography.body}"
    padding: "0 0 0 32px"
  list-row:
    backgroundColor: "{colors.midnight}"
    textColor: "{colors.porcelain}"
    typography: "{typography.body}"
  button-ink-prominent:
    backgroundColor: "{colors.porcelain}"
    textColor: "{colors.midnight}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
  button-ink-bordered:
    textColor: "{colors.porcelain}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
  symbol-cell-selected:
    backgroundColor: "{colors.porcelain}"
    textColor: "{colors.midnight}"
    rounded: "{rounded.symbol-cell}"
    height: "44px"
  line-swatch:
    rounded: "{rounded.full}"
    size: "28px"
  interchange-mark:
    backgroundColor: "{colors.midnight}"
    rounded: "{rounded.mark-tile}"
    size: "76px"
---

# Design System: Daybook

## Overview

**Creative North Star: "The Midnight Transit Diagram"**

Daybook draws a calendar the way a network map draws a city. Each calendar is a line in its own colour, each event is a station dot on that line, an event that lasts a day or more is a horizontal line with rounded ends, and today is the interchange circle. The ground is one flat colour, midnight blue in the dark appearance and porcelain in the light one, and the two swap roles as ink. There is no brand accent: every hue on screen belongs to a calendar, and categories, which cut across calendars, are told apart by symbol, never by colour.

The system is dense and quiet. Month rows take the height of their fullest day, time-grid strips grow with their lanes, and no day ends in a count of hidden events. Type is the system face at Dynamic Type text styles with tabular figures; it condenses only when a column or a single word cannot fit, and at accessibility sizes the grids give way to full-width agenda rows. Structure comes from hairlines and one step of tonal depth between ground and rail. Controls, bars, sheets and menus are the platform's own (Liquid Glass on iOS 26 and macOS 26), tinted with ink.

This record describes the SwiftUI build on branch m5-search-polish (commit eea22db). Sizes are points at the default text size; most scale with Dynamic Type. In the frontmatter a `-dark` / `-light` suffix names the two appearances of one adaptive token, and `-ic` names its value under Increased Contrast. Evidence: iPhone and iPad portrait captures in `.impeccable/review/` from one build. The Mac has not been captured since milestone 1 and iPad landscape never; statements about them describe what the code does and are marked as not visually verified.

**Key Characteristics:**
- Two grounds, one ink each, swapped between appearances; no brand accent.
- Calendar colour appears only as line (3 pt segment, 8 pt horizontal line, a coloured checkbox, a swatch) and as the tinted fill of a time-grid block.
- One mark everywhere an event stands for itself: the station mark (month row, block, agenda, day sheet, detail, search).
- Every event is on screen; rows grow, strips grow, views scroll.
- System type, tabular figures, condensed width only when a column or a single word cannot fit.
- Hairlines and one tonal step instead of shadows and cards.
- Platform controls, platform motion, ink tint.

## Colors

A two-colour world: midnight and porcelain carry every surface and every word, and the calendars bring the rest.

### Primary
- **Midnight** (`midnight`): the ground of the dark appearance and the ink of the light one; fill of the interchange circle in light.
- **Porcelain** (`porcelain`): the ground of the light appearance and the ink of the dark one; fills station dots and the interchange circle in dark.

### Neutral
- **Deep Rail** (`rail-*`): one step deeper than the ground. The sidebar, the day view's month navigator panel, the search results backdrop, and the backdrop of every list-style sheet (day sheet, calendars sheet, editors); their rows sit on it in the ground colour. The event detail (popover and sheet) is on the ground itself.
- **Station White** (`station-light`): the station dot in the light appearance, where porcelain on porcelain would vanish.
- **Secondary Ink** (`secondary-ink-*`): ink at 62%, 80% under Increased Contrast. Times, weekday names, hour labels, account headers, supporting lines, switched-off rail rows, row menu buttons, category symbols after titles.
- **Block Secondary Ink** (`block-secondary-ink-*`): ink at 80%, 90% under Increased Contrast. Time, place and category symbols inside an event block.
- **Outside Ink** (`outside-ink-*`): day numbers and event text of the neighbouring month; opaque, 4.5:1 on the ground. Under Increased Contrast, ink at 85%.
- **Rule** (`rule-*`): ink at 16%, 32% under Increased Contrast, 1 pt.
- **Weekend Tint** (`weekend-*`): a veil over Saturday and Sunday in the month, the time grid and the agenda.
- **Switch On** (`switch-on-*`): the "on" track of every switch. Ink in light; in dark an opaque grey (ink thinned to 55% over midnight), because a porcelain track would leave the white knob at 1.13:1. Holds the knob at 3.2:1.

### Calendar lines (user data)
Line colours are not tokens; they come from the system calendar store and the user can set any colour. The system owns the rules applied to them and the eight presets it offers first.

- **Line presets** (`line-preset-*`): red, orange, amber, green, teal, blue, violet, pink. Each keeps 3:1 on both grounds. The first row of the colour picker; the system colour picker follows.
- **Line fallback** (`line-fallback`): an event whose calendar cannot be resolved.
- **Line adjustment.** Every calendar colour is drawn through `Theme.line`: if it holds less than 3:1 against the ground on screen (4.5:1 under Increased Contrast), its OKLab lightness moves toward black (light ground) or white (dark ground) just far enough; hue is kept, chroma drops only where sRGB runs out. A colour that already holds is drawn as chosen. Menu swatches use the same adjusted colour.
- **Block fill.** The adjusted line mixed 22% into the ground in OKLab, then turned to the line's own hue with at least 0.045 OKLab chroma. Lightness comes from the mix, hue from the line, so a warm colour does not go grey on midnight and every chromatic calendar's fill is recognisably its own. Greys (chroma under 0.04) keep the plain mix. Opaque.

### Named Rules
**The Line Is the Only Colour Rule.** Hue on a calendar surface means "this calendar" and nothing else. Selection, today, the current time, search matches, filter state and category identity are drawn in ink, weight or symbol. The only other hue is the platform's destructive and error red on delete actions and form errors.

**The Three to One Rule.** Every calendar line holds 3:1 against the ground in the appearance on screen, 4.5:1 under Increased Contrast, by lightness alone; hue never changes.

**The Own Hue Fill Rule.** A calendar colour used as a fill is mixed 22% into the ground in OKLab and given at least 0.045 chroma in the line's hue. Never transparency, never an sRGB mix, never full strength.

**The Colour Plus Name Rule.** A calendar is never identified by colour alone: rail rows, picker rows, the detail's calendar row, day-sheet and search rows, and VoiceOver labels carry its title beside its colour.

## Typography

**Display Font:** SF Pro, the system face (no bundled fonts)
**Body Font:** SF Pro, the system face
**Label/Mono Font:** none; figures use the system face's tabular figures

**Character:** One family doing everything, differentiated by weight, width and opacity. It reads as signage: short labels, aligned figures, no decoration.

### Hierarchy
All roles are Dynamic Type text styles unless stated; sizes are the iOS defaults.

- **Period title** (bold 22 pt, fixed; Mac toolbar): the period, then the year in regular weight and secondary ink. Not visually verified on Mac.
- **Bar title** (headline, semibold 17 pt; iPad bar, growing only to xxLarge): the period in its longest form that fits. On iPhone the navigation bar's inline title, short form.
- **Title** (bold, title2): the event name in the detail, the first-run headline. Title3 for the editor's title field (semibold), the agenda's day number (bold) and the Mac rail's "Daybook" (bold).
- **Headline** (semibold, 17 pt): the navigator's month name; "Dříve" above past search results.
- **Body** (regular, 17 pt): rail names, add rows, form rows, titles in the day sheet, agenda and search.
- **Day number** (semibold callout 16 pt; footnote 13 pt in columns under 130 pt): tabular, month cells and grid headers.
- **Detail** (regular subheadline 15 pt): supporting lines in the detail, day sheet and search rows; search day headers.
- **Event row** (regular caption 12 pt; caption2 11 pt and condensed under 130 pt; subheadline on Mac): time and title in a month cell.
- **Label** (semibold caption 12 pt): weekday header, block titles, section labels in the detail. Sentence case, no tracking.
- **Micro** (regular caption2 11 pt, tabular): hour labels, time and place in a block. Semibold for the title set into a span line.

### Times
One time format per locale, from `TimeText`: the locale's hours and minutes ("8:30" in Czech, "08:30" in British English) on the hour axis, in rows, blocks, the detail and search. A range is two times joined by an en dash with no spaces ("13:00–14:30"); an event crossing midnight writes each end with its date, joined by a spaced en dash.

### Named Rules
**The Tabular Figures Rule.** Every number that sits in a column uses tabular figures. In a month row the time is right-aligned in a slot as wide as "00:00", so titles share one left edge.

**The No Broken Words Rule.** Text never breaks inside a word. Rail names, add rows and block titles wrap between words; a title that cannot wrap holds one line with a tail ellipsis; a block's time shows as a range, then a start, then not at all; a place shows only if its first word fits.

**The Condense Only When a Word Cannot Fit Rule.** Grids condense as a whole below 130 pt columns. A wrapping name condenses only when its longest single word is wider than its column; otherwise it stays at standard width and wraps.

**The Weight Not Colour Rule.** Emphasis inside text, such as the matched letters of a search, is semibold, never a hue.

## Layout

**Shell, regular width (iPad; Mac by code).** A split view: the rail at 248 pt (220 to 320) and the calendar in the detail column. iPad bar, leading to trailing: the period title, the filter indicator when the rail is hidden, then back / Today / forward, the view switcher, search and a plus. The bar is measured, not guessed, and chooses the first arrangement that fits in this priority: the longest title form (full weekday and month down to numerals), then the filter's longest form ("Skryto: N", then the count, then the symbol), then the switcher as a segmented control, then a menu titled with the view and an up-down chevron, then the menu without the chevron. The plus is always icon-only on iPad. While search is open the period controls leave and the title reads "Hledání". Mac: a fixed 22 pt title item, a "Skryto: …" chip (the hidden item's name when one, the count when several), segmented switcher, search, and "Událost" with a plus; the toolbar is opaque ground. Mac and iPad landscape are not visually verified.

**Shell, compact width (iPhone).** Top bar: the calendars button, the title, back / Today / forward. Bottom bar: segmented switcher, search, plus. The calendars and categories list rises as a sheet (medium and large detents). While a filter hides anything the calendars button becomes the filter symbol.

**Filter indicator.** iPad with the rail on screen: the filter symbol and count at the rail's top; with the rail hidden: beside the title, tapping it opens the rail. VoiceOver and the pointer get the names ("Skryté: Práce a Porady").

**Rail.** A list: the day view's month navigator first when the day has no room for it beside itself, then calendars grouped by account, "+ Nový kalendář", then the categories section ending in "+ Nová kategorie" and the storage line. Rows share one trailing column: calendar locks and category menu buttons centre on one line (the menu symbol drawn 32 pt wide, 10 pt into the trailing inset; 44 pt target).

**Month.** A weekday header over seven equal columns with no gutters. A week row is the day number (28 pt) plus one 17 pt row per lane of its fullest day plus a 6 pt foot. Spare height is shared in proportion to need. Spans sit in shared lanes under the day numbers; timed events stack below. The month is one continuous scroll of the focused month and three either side; the title and the dimming follow the month owning most of the viewport. iPhone opens on today's week.

**Time grid (week and day).** A 46 pt hour gutter, 52 pt per hour, day columns never under 110 pt; week shows seven (three on iPhone) and pages a day at a time when fewer fit, the gutter staying. Blocks are never shorter than half an hour; overlaps share the column with 2 pt gaps. All-day lanes 20 pt above the grid, growing with their lanes; in paged columns each label slides to the visible edge. The grid opens one hour before now on today's period, 7:00 otherwise. Regular width: a 300 pt month navigator on the rail colour beside the day when the day keeps 400 pt.

**Accessibility sizes.** The time grid always, and the month when its columns are under 130 pt, become the agenda: one full-width row per day, a 64 pt column with the day number (34 pt interchange circle for today) and weekday, then each event with its station mark, title, time and category names. Rail rows move captions and locks under the name and the menu button to the checkbox's line; bars over scrolling lists become opaque.

**Insets.** Cell content 6 pt (3 pt narrow); event rows 8 pt (4 pt narrow); panels 12 pt; popover content 16 pt (popover 360 pt wide, up to 560 tall); sheet content 20 pt; first-run screen 32 pt around a 440 pt measure.

**Targets.** 44 pt on touch: swatches, symbol cells, navigator days, day headers, row menu buttons, the day number's hit area on iPad. iPhone: a tap anywhere in a month day opens its sheet. Mac and iPad: events open their own detail popover, the day number opens the day view, a double click on empty space creates an event.

### Named Rules
**The Nothing Hidden Rule.** A day shows every event of its enabled calendars and categories. Rows grow, strips grow, views scroll; no cell ends in "+3 more", a dot or a count. When a filter hides something, the shell says so.

**The Rows Before Columns Rule.** When columns cannot hold a title at the current text size, the layout becomes full-width rows. It does not shrink type and it does not drop events.

**The Title First Rule.** Where a bar must give way, the period title keeps its longest form first; controls take compact forms before the title shortens.

## Elevation & Depth

Flat. The build declares no shadow. Depth is one tonal step: rail and list-sheet backdrops are deeper than the ground, and their rows return to the ground colour. Everything else is separated by 1 pt rules.

Sheets, popovers, bars, menus and bar buttons use the platform's own material (Liquid Glass) and are not restyled, except that sheet backgrounds are set to the rail or ground colour and some bars are made opaque (the Mac toolbar, the agenda's bar, list sheets at accessibility sizes) so text never blurs through them.

### Named Rules
**The One Step Rule.** There are two surface levels, ground and rail. A new surface is one of them; it does not introduce a third tone, a gradient or a shadow.

## Shapes

The geometry is a diagram's: straight segments, true circles, small radii only where a line ends.

- **Lines** are square-cut: 3 pt wide vertically, 8 pt tall horizontally. A span line's ends round (4 pt) only where the event really starts or ends.
- **Stations** are 7 pt circles with a 1.5 pt ring in the line colour, overhanging the 3 pt line.
- **The interchange** is a filled ink circle around today's number (22 pt month, 26 pt grid header, 32 pt navigator, 34 pt agenda) and, at 11 pt with a 2 pt ground ring, at the head of the now line.
- **Selection** is an ink ring (1.5 pt in the navigator, 2 pt round a chosen swatch), or, in the symbol grid, an ink-filled 8 pt rounded cell with the symbol reversed out.
- **Blocks** are rectangles with 4 pt corners.
- **The interchange mark** sits on a midnight tile with the platform's continuous icon corner (17 pt at 76 pt) and a rule-coloured hairline.
- Grouped sections, sheets, buttons and bar controls keep the platform's own shapes (capsule buttons, inset rounded list sections).

## Components

### Station Mark
The signature. A 3 pt piece of the calendar's line with a 7 pt station dot centred on it. It stands for an event in month rows, the agenda, the day sheet, search results, and the detail's calendar row (22 pt tall there); in a block the dot sits 4 pt from the top. Days outside the month draw it at 60% opacity.

### Event Row
One 17 pt line: station mark, time in secondary ink (in the "00:00" slot), title in ink, then the event's category symbols when title and symbols fit together. Inset 8 pt, gaps 6 pt; under 130 pt columns inset 4 pt, gaps 4 pt, no time, condensed type. Outside-month rows use outside ink.

### Span Line
An all-day or multi-day event: a short stub (10 pt, 6 pt narrow), the title set into it in semibold micro type with category symbols when they fit, then the line runs on to the event's end. A one-day event is the stub and title alone.

### Event Block
A timed event in week and day: the line down the left edge (inset 2 pt) with a station dot at the top, on the Own Hue Fill. Title semibold label in ink, wrapping between words as many lines as the block holds; time and place in micro type and block secondary ink, category symbols after the time where both fit. Condensed as a grid, not per block.

### Now Line
On today's column: an 11 pt interchange circle and a 2 pt ink line, updated every minute.

### Rail Rows
- **Calendar:** a large checkbox symbol (filled square with check when on, empty square when off) in the calendar's adjusted line colour, the name in ink (secondary ink when off), "sdílený" under it in caption, a lock in the trailing column for read-only calendars. One tap toggles; the context menu offers show only, show all and change colour.
- **Category:** the checkbox in ink (secondary when off), the category's symbol in a 22 pt column, the name wrapping between words, and a `ellipsis.circle` menu button in secondary ink in the trailing column offering rename, change symbol, show only, show all and delete (the same items as the context menu). "Bez kategorie" has the same columns and no menu.
- **Add row:** a plus in a 24 pt column, 8 pt gap, the title in its own column wrapping between words, in ink.
- **Not saved:** when categories cannot sync, a warning row at the top of the categories section (and atop the category editor): a filled triangle and a semibold title in ink, the advice in secondary ink. It replaces the sync footer.

### Category Symbols
Categories carry no colour. After a title (month row, span, block, search row) their SF Symbols are drawn filled, in secondary ink (block secondary ink in blocks), only when title and symbols fit whole; they never take room from the title. In full-width rows and the detail, symbol and name are written together.

### Interchange Circle
Today's number reversed out of a filled ink circle. On a calendar surface nothing else is a filled ink shape.

### Month Navigator
A small month drawn in the system's marks: 32 pt cells (44 pt targets on touch), today in the interchange circle, the shown day in an ink ring, both bold; neighbouring days in outside ink; chevrons page the month. Beside the day on its rail-coloured panel, or at the top of the rail.

### Search Results
Results grouped by day on the rail backdrop, rows in the ground colour; upcoming days first, then past days under a "Dříve" heading. A row: station mark, title with matched letters in semibold, the time (or "Celý den", or both dates), the place, a matched fragment from a note or attendee after a small symbol (one line, tail ellipsis), then the calendar's name and the category symbols, all supporting lines in secondary ink. A switch above the results includes switched-off calendars and categories; with no results, the empty state offers it as a bordered ink button.

### Sheets, Popover and Forms
Day sheet, calendars sheet, event editor, calendar editor, category editor: rail backdrop, rows in ground, platform grouped style, Cancel and confirm in the bar. Event detail: on the ground, popover on Mac and iPad, sheet on iPhone. Its title is bold title type; facts are rows of a secondary-ink symbol and a value; the calendar is a station mark beside its name and account; section labels are semibold label type in secondary ink; links are ink and underlined.

### Buttons and Switches
- **Ink bordered:** the platform's bordered button tinted with ink (Upravit, Pozvat účastníky, Nový kalendář, the search empty state).
- **Ink prominent:** bordered-prominent, ink fill with the label in the ground colour, large. The first-run action only.
- **Destructive:** bordered, system red, always behind a confirmation dialog.
- **Bar buttons:** untinted platform controls. Menus, disclosure groups and form controls are tinted ink.
- **Switches:** tinted Switch On.

### Line Swatch
28 pt circles of the presets in 44 pt targets, one row of eight where the form is wide enough, else two of four; the chosen one in a 2 pt ink ring. In menus and pickers a 12 pt dot of the adjusted line colour precedes the calendar's name.

### First Run
The interchange mark (76 pt, scaling with title2, at most 120 pt), a bold title2 headline, the explanation in secondary ink, centred in a 440 pt measure, and the ink prominent button below. When it does not fit (accessibility sizes) the text scrolls and the button stays pinned at the bottom on the ground above a rule. The same diagram, drawn by `scripts/make-app-icon.swift`, is the app icon: midnight tile, red, green and blue preset lines with white stations, a porcelain interchange circle.

### Motion
Platform motion only. Switching a calendar or category re-lays out with the system's default spring, so month rows and blocks close up; under Reduce Motion the content crossfades instead. Day / week / month, and calendar / search results, crossfade at the system's default timing. Sheets, popovers, menus and the rail move as the system moves them.

## Do's and Don'ts

### Do:
- **Do** draw calendar colour only as line, checkbox, swatch or the Own Hue Fill, always through the line adjustment for the ground on screen.
- **Do** mark selection, today, the current time, search matches and filter state in ink, weight or symbol.
- **Do** use the station mark wherever a row stands for one event.
- **Do** put new list sheets on the rail colour with rows in the ground colour; reading surfaces (the detail) go on the ground.
- **Do** write every time through `TimeText`, and set aligned figures tabular.
- **Do** give new rail rows the shared trailing column, a 44 pt target and names that wrap between words.
- **Do** provide the agenda fallback for any new grid at accessibility sizes.
- **Do** give every adaptive colour an Increased Contrast value, and check text on a block against 4.5:1 and any new preset against 3:1 on both grounds.
- **Do** build new metrics as scaled metrics tied to a text style.

### Don't:
- **Don't** hide events behind a count, a dot or a "more" link in any view.
- **Don't** give the interface a hue of its own; a blue control or highlight reads as a calendar line.
- **Don't** give categories colours; they are told apart by symbol.
- **Don't** fill with a calendar colour at full strength, by opacity, or by an sRGB mix.
- **Don't** add shadows, gradients or a third surface tone.
- **Don't** round the end of a span line where the event continues.
- **Don't** let text break inside a word, or condense text that would fit by wrapping.
- **Don't** let category symbols take room from a title.
- **Don't** replace the navigator, the station mark or the interchange circle with system pickers or badges that bring their own accent.
