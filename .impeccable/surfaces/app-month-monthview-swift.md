---
version: 1
slug: "app-month-monthview-swift"
primary_target: "App/Month/MonthView.swift"
related_targets: ["App/Shell/RootView.swift"]
---

# Month view

Scope: the month view on Mac, iPad and iPhone, and the shell around it (sidebar, toolbar). Visitor mode: Operate.

Audience and job: someone with work, personal and shared calendars who needs to see everything planned in a month at once and trust nothing is hidden. Task: scan a full month, spot busy days and conflicts, open or create an event. Constraints: native SwiftUI controls, Dynamic Type, both appearances, calendar colours chosen by the user in the system.

Memorable moment: a dense month where every event is on screen and the calendars read as coloured lines running down the days.

Unresolved: exact brightness adjustment of user-chosen calendar colours on the light ground.

## Direction contract

THESIS: The month never truncates. Week rows grow to the fullest day, so every event is on screen. It refuses the category default of equal-height cells that end in "+3 more".

OWN-WORLD: Midnight transit diagram. Dark appearance: midnight-blue ground (#0e1a3a), darker rail (#0a1430), porcelain white text and station dots (#f4f1ea). Light appearance: porcelain ground, midnight text, same line colours. Each calendar is a line in its own colour; each event is a white station dot on that line; multi-day events are horizontal lines with rounded ends; today is a white interchange circle. System font, tabular figures, hairline rules at low opacity.

STORY: The user sees the whole month, understands which calendar each event belongs to by its line, believes nothing is hidden, and acts by clicking an event or an empty day.

FIRST VIEWPORT: Mac, 1440 x 900. Left rail 248 pt: app name, calendars grouped by account with coloured checkboxes, then categories. Toolbar: month and year at 22 pt bold, back, Today, forward, Day / Week / Month segmented control at right, search field, "+ Event" as the primary action at the far right. Below: weekday header, then six week rows of unequal height filling the rest. Each cell: day number top left, multi-day lines, then one 16 pt row per event with line, station dot, time, title.

FORM: catalog world adopted from the dealt hand (competitive challenger, not from the grounded list). seed:18c4b004cc48db7e

Signature interaction: turning a calendar off in the rail removes its line from every day at once and the week rows close up. Motion grammar: system transitions only; row height changes animate with the default spring, crossfade under Reduce Motion.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
