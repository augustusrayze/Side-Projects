# Saint of the Day — iOS App

A free, native iOS app that surfaces the Catholic Saint of the Day every morning with a rich biographical profile: classic icon image, life summary, time period, miracles, writings, patronages, and more.

Built entirely with Swift / SwiftUI. No backend required.

## Features

- Daily saint profile fetched from Vatican News + Wikipedia
- Classic icon imagery for each saint
- Sections: Biography, Miracles, Writings, Patronages, Canonization
- Local notification at 8:00 AM (device timezone) — no backend needed
- Disk cache for same-day offline access
- Parchment / Byzantine visual aesthetic
- Wikipedia attribution (CC BY-SA 4.0 compliant)

## Data Sources

| Source | Used For |
|---|---|
| Vatican News | Authoritative feast day → saint name |
| Wikipedia MediaWiki API | Full biography, image, structured content |

## Requirements

- Xcode 15+, iOS 17.0+
- Apple Developer account (for App Store distribution)
- No external Swift Package dependencies

## Getting Started

1. Open `SaintOfTheDay.xcodeproj` in Xcode
2. Set your Team in Signing & Capabilities
3. Update `PRODUCT_BUNDLE_IDENTIFIER` in Build Settings (replace `com.yourname`)
4. Add a `PlaceholderSaint` image to `Assets.xcassets/PlaceholderSaint.imageset` (Byzantine-style silhouette, public domain image from Wikimedia Commons recommended)
5. Run on Simulator or device

## Project Structure

```
SaintOfTheDay/
├── SaintOfTheDayApp.swift     # @main entry point
├── Models/                    # Saint, SaintSection
├── Services/                  # Data pipeline + notifications
├── ViewModels/                # TodayViewModel, SettingsViewModel
├── Views/
│   ├── Today/                 # Main daily screen
│   ├── Detail/                # Full saint biography scroll
│   ├── Onboarding/            # First-launch notification prompt
│   ├── Settings/              # Notification status + attribution
│   └── Shared/                # Reusable components
└── Extensions/                # Color, Font, View theme tokens
```

## Architecture

**MVVM + Services**
- `@Observable` ViewModels (iOS 17 macro)
- `async/await` throughout — no Combine
- Two-stage data pipeline: Vatican News (HTML) → Wikipedia (JSON API)
- Disk cache keyed by date; `URLCache.shared` for images

## Notes

- The app is light-mode only (parchment aesthetic)
- Notifications are local (on-device); no push notification backend required
- Wikipedia content license: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
