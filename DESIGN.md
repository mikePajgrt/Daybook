---
name: Daybook
description: A calendar for iOS and macOS that draws every event of the month as a station on its calendar's line.
colors:
  midnight: "#0e1a3a"
  porcelain: "#f4f1ea"
  rail-dark: "#0a1430"
  rail-light: "#eae6dd"
  station-light: "#ffffff"
  outside-ink-dark: "#8f97ad"
  outside-ink-light: "#5b6278"
  secondary-ink-dark: "rgba(244, 241, 234, 0.62)"
  secondary-ink-light: "rgba(14, 26, 58, 0.62)"
  block-secondary-ink-dark: "rgba(244, 241, 234, 0.8)"
  block-secondary-ink-light: "rgba(14, 26, 58, 0.8)"
  rule-dark: "rgba(244, 241, 234, 0.16)"
  rule-light: "rgba(14, 26, 58, 0.16)"
  weekend-dark: "rgba(0, 0, 0, 0.18)"
  weekend-light: "rgba(14, 26, 58, 0.05)"
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
  full: "9999px"
spacing:
  hairline: "1px"
  block-gap: "2px"
  cell-inset-compact: "3px"
  cell-inset: "6px"
  panel: "12px"
  popover: "16px"
  sheet: "20px"
  gate: "32px"
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
  sheet-row:
    backgroundColor: "{colors.midnight}"
    textColor: "{colors.porcelain}"
    typography: "{typography.body}"
  rail:
    backgroundColor: "{colors.rail-dark}"
    textColor: "{colors.porcelain}"
    width: "248px"
  line-swatch:
    rounded: "{rounded.full}"
    size: "28px"
---

# Design System: Daybook

## Overview

**Creative North Star: "The Midnight Transit Diagram"**

Daybook draws a month the way a network map draws a city. Each calendar is a line in its own colour, each event is a station dot on that line, an event that lasts several days is a horizontal line with rounded ends, and today is the interchange circle. The ground is one flat colour, midnight blue in the dark appearance and porcelain in the light one, and the two swap roles as ink. There is no third brand colour: every other colour on screen belongs to a calendar and was chosen by the user.

The system is dense and quiet. Week rows take the height of their fullest day, so the grid is uneven on purpose and no day ends in a count of hidden events. Type is the system face at Dynamic Type text styles with tabular figures, condensed when a column gets narrow. Structure comes from hairlines at low opacity and one step of tonal depth between the ground and the rail; controls, sheets and bars are the platform's own.

This record describes the SwiftUI build for iOS 26 and macOS 26. Sizes are points at the default text size and scale with Dynamic Type. Values in the frontmatter with a `-dark` or `-light` suffix are the two appearances of one adaptive token; `midnight` and `porcelain` are ground in one appearance and ink in the other.

**Key Characteristics:**
- Two grounds, one ink each, swapped between appearances; no brand accent.
- Calendar colour appears only as line: a 3 pt vertical segment, an 8 pt horizontal line, a 22% tint of a block.
- Every event is on screen; rows grow, cells never collapse into a count.
- System type, tabular figures, condensed width under 130 pt columns.
- Hairlines and one tonal step instead of shadows and cards.
- Platform controls and platform motion.

## Colors

A two-colour world: midnight and porcelain carry every surface and every word, and the calendars bring the rest.

### Primary
- **Midnight** (`midnight`): the ground of the dark appearance and the ink of the light one. Also the fill of the interchange circle in the light appearance.
- **Porcelain** (`porcelain`): the ground of the light appearance and the ink of the dark one. Fills station dots and the interchange circle in the dark appearance.

### Neutral
- **Deep Rail** (`rail-dark`, `rail-light`): one step deeper than the ground. The sidebar, the month navigator panel, and the backdrop of every sheet and grouped form; form rows and list rows sit on it in the ground colour.
- **Station White** (`station-light`): the station dot's fill in the light appearance, where porcelain on porcelain would vanish. In the dark appearance the dot is porcelain.
- **Secondary Ink** (`secondary-ink-*`): ink at 62%. Times, weekday names, hour labels, account headers, supporting lines in sheets.
- **Block Secondary Ink** (`block-secondary-ink-*`): ink at 80%. Time and place inside a tinted event block, where 62% would fall under 4.5:1.
- **Outside Ink** (`outside-ink-*`): day numbers and event text for days of the neighbouring month. Opaque values that hold 4.5:1 on the ground; under Increased Contrast they become ink at 85%.
- **Rule** (`rule-*`): ink at 16%, 1 pt. Between days, between weeks, under headers, at every hour.
- **Weekend Tint** (`weekend-*`): a veil over Saturday and Sunday columns in the month, the time grid and the agenda.

### Calendar lines (user data)
Line colours are not tokens. They come from the system calendar database and the user can set any colour. The system owns only the rules that apply to them and the eight presets it offers first.

- **Line presets** (`line-preset-*`): red, orange, amber, green, teal, blue, violet, pink. Each keeps 3:1 against both grounds. Offered as the first row of the colour picker; the system colour picker follows for any other colour.
- **Line fallback** (`line-fallback`): drawn when an event's calendar cannot be resolved.

### Named Rules
**The Line Is the Only Colour Rule.** Hue on a calendar surface means "this calendar" and nothing else. Interface state, selection and emphasis are drawn in ink: the selected day is an ink ring, today is an ink circle, the current time is an ink line.

**The Thinned Line Rule.** A calendar colour used as a fill is mixed 22% into the ground in OKLab, never laid over it as transparency and never mixed in sRGB. The result is opaque, keeps ink legible on it, and keeps warm colours from turning brown on midnight.

**The Colour Plus Name Rule.** A calendar is never identified by colour alone. Wherever a calendar is chosen or named (sidebar, picker rows, event detail, day sheet, VoiceOver labels) its title is beside the colour.

## Typography

**Display Font:** SF Pro, the system face (no bundled fonts)
**Body Font:** SF Pro, the system face
**Label/Mono Font:** none; figures use the system face's tabular figures

**Character:** One family doing everything, differentiated by weight, width and opacity. It reads as signage: short labels, aligned figures, no decoration.

### Hierarchy
All roles are Dynamic Type text styles; sizes below are the iOS defaults.

- **Period title** (bold, 22 pt fixed on Mac; the navigation bar's inline title on iOS): the period on screen. On Mac the year follows in regular weight and secondary ink.
- **Title** (bold, title2, 22 pt): the event's name in the detail, the headline of the access screen. Title3 (20 pt) carries the editor's title field at semibold and the agenda's day number at bold.
- **Headline** (semibold, 17 pt): the month name above the month navigator.
- **Body** (regular, 17 pt): event titles in the day sheet and the agenda, form rows, sidebar calendar names.
- **Day number** (semibold, callout 16 pt; footnote 13 pt in columns under 130 pt): tabular. Day numbers in the month and in time-grid headers.
- **Detail** (regular, subheadline 15 pt): date and time under a detail title, the supporting line of a day-sheet row.
- **Event row** (regular, caption 12 pt; caption2 11 pt and condensed in columns under 130 pt; subheadline on Mac): time and title of an event in a month cell.
- **Label** (semibold, caption 12 pt): weekday header, event block titles, section labels inside the detail. Sentence case, no tracking.
- **Micro** (regular, caption2 11 pt, tabular): hour labels, time and place inside a block. Semibold for the label set into a span line.

### Named Rules
**The Tabular Figures Rule.** Every number that sits in a column is set with tabular figures: day numbers, times, hour labels. In a month row the time is right-aligned in a slot as wide as "00:00", so titles share one left edge.

**The Condense Before You Cut Rule.** When a column is narrower than 130 pt, type switches to the condensed width and insets tighten before anything is removed. The month row then drops its time; the title stays.

**The No Broken Words Rule.** Text in a cell or block never wraps inside a word. Titles hold one line with a tail ellipsis (two lines in blocks 140 pt or wider); a time shows as a range, then as a start, then not at all, whichever fits whole.

## Layout

**Shell.** Regular width (Mac, iPad): a split view with the rail at 248 pt (220 to 320) and the calendar in the detail column; the toolbar holds the period title, the Day / Week / Month segmented control, the new-event button and back / Today / forward. Compact width (iPhone): one column; the top bar holds the calendars button, the title and back / Today / forward, the bottom bar holds the segmented control and the new-event button; the calendars list rises as a sheet.

**Month.** A weekday header over seven equal columns with no gutters; hairlines separate days and weeks. A week row's height is day number (28 pt) plus one row (17 pt) per lane of its fullest day plus a 6 pt foot. Spare viewport height is shared between weeks in proportion to what they need, so busy weeks stay the tall ones. Span lines occupy shared lanes directly under the day numbers; timed events stack below them. Where the month does not fit (iPhone) it scrolls and opens on today's week.

**Time grid (week and day).** An hour gutter of 46 pt, then day columns never narrower than 110 pt; when fewer than seven fit, days page horizontally while the gutter stays. An hour is 52 pt. A block is never shorter than half an hour; overlapping blocks share the column side by side with 2 pt gaps. All-day events sit in a strip above the grid, 20 pt per lane, and the strip grows with its lanes. On regular width the day view places a 300 pt month navigator beside the day when the day keeps at least 400 pt; otherwise the navigator moves to the foot of the rail.

**Agenda fallback.** At accessibility text sizes the time grid, and the month in columns under 130 pt, become full-width rows, one per day: a 64 pt column with the day number and weekday, then every event with its station mark, title and time.

**Insets.** Cell content 6 pt from the column edge (3 pt in narrow columns); panels 12 pt; popover content 16 pt; sheet content 20 pt; the access screen 32 pt around a 440 pt measure.

**Targets.** Tappable marks keep 44 pt: colour swatches, day headers. On iPhone a tap anywhere in a day opens that day's sheet; on Mac and iPad events open their own detail, the day number opens the day view, and a double click on empty space creates an event.

### Named Rules
**The Nothing Hidden Rule.** A day shows every event of its enabled calendars. Rows grow, strips grow, views scroll; no cell ends in "+3 more", a dot, or a count.

**The Rows Before Columns Rule.** When columns cannot hold a title at the current text size, the layout changes to full-width rows. It does not shrink type and it does not truncate the list.

## Elevation & Depth

Flat. The build declares no shadow anywhere. Depth is one tonal step: the rail and sheet backdrops are deeper than the ground, and content rows on a sheet return to the ground colour. Everything else is separated by 1 pt rules.

Sheets, popovers, toolbars and bar buttons use the platform's own material and elevation (Liquid Glass on iOS 26 and macOS 26) and are not restyled, except that sheet backgrounds are set to the rail colour and the Mac toolbar and the agenda's navigation bar are given an opaque ground.

### Named Rules
**The One Step Rule.** There are two surface levels, ground and rail. A new surface is one of them; it does not introduce a third tone, a gradient or a shadow.

## Shapes

The geometry is a diagram's: straight segments, true circles, and small radii only where a line ends.

- **Lines** are square-cut rectangles: 3 pt wide vertically, 8 pt tall horizontally. A span line's ends are rounded (4 pt) only where the event really starts or ends; where it continues into the next week the end is cut flush with the row edge.
- **Stations** are 7 pt circles with a 1.5 pt ring in the line colour, centred on a line wider than they are narrow, so the dot overhangs the line.
- **The interchange** is a filled ink circle: around today's number (22 pt in the month, 26 pt in grid headers, 34 pt in the agenda, 32 pt in the navigator) and, at 11 pt with a 2 pt ground ring, at the head of the current-time line.
- **Selection** is an ink ring, 1.5 pt around the shown day in the navigator and 2 pt around the chosen colour swatch.
- **Blocks** are rectangles with softly cut corners (4 pt).
- Grouped form sections, sheets and toolbar controls keep the platform's own corner shapes.

## Components

### Station Mark
The signature. A 3 pt segment of the calendar's line with a 7 pt station dot on it, standing at the start of every timed event: in month rows (dot centred), in agenda rows, and in event blocks (dot 4 pt from the top). On days outside the month the mark drops to 60% opacity.

### Event Row
One line, 17 pt tall: station mark, time in secondary ink, title in ink. Inset 8 pt, gaps 6 pt; in columns under 130 pt inset 4 pt, gaps 4 pt, no time, condensed type. Text for days outside the month uses outside ink.

### Span Line
An all-day or multi-day event. The line starts with a short stub (10 pt, 6 pt when narrow), carries the title set into it in semibold micro type, and runs on to the event's end. Within a single day it is the stub and the title alone. In a paged time grid the label slides along its line to stay at the visible edge, and the stub lengthens so the line stays unbroken.

### Interchange Circle
Today. An ink-filled circle with the day number reversed out in the ground colour. Nothing else on a calendar surface uses a filled ink shape of this kind.

### Event Block
A timed event in the week and day views: the calendar's line down the left edge with a station dot at the top, on a fill that follows the Thinned Line Rule. Title in semibold label type and ink; time and place in micro type and block secondary ink, shown only when the block has the height for them. Blocks are condensed as a grid, not one by one.

### Now Line
The current time on today's column: an 11 pt interchange circle and a 2 pt ink line across the column, updated every minute.

### Rail
Calendars grouped by account under secondary-ink headers. Each row is a filled checkbox in the calendar's own colour (an empty square when off), the title (secondary ink when off), a small "shared" line where it applies and a lock for read-only calendars. One tap toggles; the context menu offers show only this, show all and change colour. A plain "new calendar" row ends the list.

### Month Navigator
A small month drawn in the system's own marks rather than the system date picker: 32 pt cells, today in the interchange circle, the shown day in an ink ring, neighbouring-month days in outside ink, chevrons to page.

### Sheets and Forms
Day sheet, event detail, event editor and calendar editor. Backdrop in the rail colour, rows in the ground colour, platform grouped form style, platform Cancel and confirm buttons in the bar. In the day sheet and the detail the calendar is shown as a 4 pt capsule of its colour beside its name. The detail's title is bold title type; its facts are rows of a secondary-ink symbol and a value; section labels are semibold label type in secondary ink.

### Buttons
Platform styles. Toolbar and bar buttons are untinted system controls. In-content actions are bordered buttons tinted with ink; links are tinted with ink and underlined. Delete uses the system's destructive red and a confirmation dialog.

### Line Swatch
A 28 pt circle of a preset colour in a 44 pt target, four to a row; the chosen one carries a 2 pt ink ring. In menus and pickers a 12 pt dot of the calendar's colour precedes its name.

### Motion
Platform transitions only. Switching between day, week and month crossfades (0.2 s, ease in and out). Sheets, popovers and menus move as the system moves them.

## Do's and Don'ts

### Do:
- **Do** draw calendar colour only as line: a 3 pt vertical segment, an 8 pt horizontal line, or a 22% OKLab tint of a block.
- **Do** mark selection, today and the current time in ink (ring, filled circle, 2 pt line).
- **Do** put new sheets on the rail colour with their rows in the ground colour.
- **Do** set every figure that aligns in a column with tabular figures.
- **Do** switch to condensed width below 130 pt columns, and to full-width rows at accessibility text sizes.
- **Do** keep a calendar's name next to its colour wherever a calendar is identified.
- **Do** check any new text colour on a tinted block against 4.5:1 in both appearances, and any new preset line colour against 3:1 on both grounds.
- **Do** build new metrics as scaled metrics tied to a text style, so they grow with Dynamic Type.

### Don't:
- **Don't** hide events behind a count, a dot or a "more" link in any view.
- **Don't** give the interface a hue of its own on a calendar surface; a coloured control reads as a calendar line.
- **Don't** fill a block or a row with a calendar colour at full strength, or thin it with opacity instead of the OKLab mix.
- **Don't** add shadows, gradients or a third surface tone.
- **Don't** round the end of a span line where the event continues into another week.
- **Don't** let text break inside a word; truncate the title, then drop the time.
- **Don't** replace the navigator, the station mark or the interchange circle with system pickers or badges that bring their own accent colour.
