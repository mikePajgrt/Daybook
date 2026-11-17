# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

SwiftUI, one shared codebase for iPhone, iPad and Mac. Minimum iOS 26 and macOS 26 (native macOS target, not Catalyst). Xcode project generated with XcodeGen. Calendar data through EventKit (system accounts); app-owned data (categories and their assignments) in SwiftData synced through CloudKit.

## Users

People who run several calendars at once: a work Exchange account, a personal iCloud or Google account, and Google calendars other people share with them. They plan across all of them and need the whole picture in one place, on iPhone and on Mac. Distributed publicly through the App Store, so first-run users are strangers who have not been told how the app works.

## Product Purpose

Daybook is a calendar for iOS and macOS that shows every event from every enabled calendar without hiding any. It exists because existing calendars collapse busy days into "+3 more" or dots, and become unreadable in months with many events. Success: a user can look at a month and trust that what they see is everything planned, and can still read it when the month is full.

## Positioning

The month view never truncates. Every event planned for a day (within the enabled calendars) is visible in that day's cell, and the layout stays legible when a month is dense. Categories cut across accounts and calendars, which the providers themselves do not offer.

## Operating Context

- Calendars come from accounts the user has added in system Settings: iCloud, Exchange, Google, including Google calendars shared with the user (these appear once enabled for sync on Google's side). Daybook does not sign in to providers itself.
- Some calendars are read-only (typically shared ones); they are displayed and can be categorised, but not edited.
- Used on iPhone in short glances and on Mac in longer planning sessions.

## Capabilities and Constraints

- Views: day, week, month.
- Month view shows all events of each day in the day's cell, respecting which calendars are switched on.
- Search across events.
- Switch individual calendars on and off.
- Create calendars. EventKit constraint: new calendars can be created in iCloud, local and Exchange sources, not in a Google account.
- Create and edit events (meetings).
- Calendars are distinguished by colour.
- Events can be given categories. Categories are Daybook's own data (EventKit has no such field), stored outside the event, synced between the user's devices through iCloud, invisible to other apps and other attendees. They work on read-only calendars too.
- CloudKit sync requires a paid Apple Developer account.
- Undecided: monetisation, localisation languages beyond Czech and English, iPad-specific layout scope, widgets, notifications beyond what the system already provides.

## Evidence on Hand

None. No existing assets, logo, copy, screenshots, user data or testimonials. The name "Daybook" is the repository name; it has not been confirmed as the public product name. Future work must not invent reviews, user counts or pricing.

## Product Principles

1. Nothing is hidden. If an event is planned and its calendar is on, it is on screen in the view that covers that day.
2. Density must stay readable. Showing everything is only useful if a full month can still be scanned.
3. The user's accounts stay the source of truth. Daybook reads and writes the system calendar store and adds only what the providers lack.
4. Calendar control is immediate. Turning calendars on and off, and telling them apart, takes one action and no hunting.
5. Finding beats browsing. Any event, past or future, is reachable by search.

## Accessibility & Inclusion

App Store public release: Dynamic Type, VoiceOver, Dark Mode and Increased Contrast must work. Calendar and category colours cannot be the only carrier of meaning, since users choose them freely and some users cannot distinguish them.
