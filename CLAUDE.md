# NotionQuotesWidget — Agent Guide

macOS SwiftUI app + WidgetKit extension that displays rotating quotes from a Notion database.
See [README.md](README.md) for setup, signing, and Notion configuration details.

## Build

Requires `xcodegen` (`brew install xcodegen`), Xcode 16+, macOS 14+ deployment target.

```bash
xcodegen generate          # regenerate .xcodeproj from project.yml
xcodebuild -scheme NotionQuotes -configuration Debug build
```

Re-run `xcodegen generate` after **any** change to `project.yml`.

## Architecture

Two targets defined in [project.yml](project.yml); both compile `Shared/`:

| Target | Type | Directory |
|--------|------|-----------|
| `NotionQuotes` | macOS app | `NotionQuotes/` + `Shared/` |
| `NotionQuotesWidgetExtension` | WidgetKit extension | `NotionQuotesWidget/` + `Shared/` |

**Pattern**: MVVM in the app (`AppViewModel` → `ContentView`). The widget uses `AppIntentTimelineProvider`.

### Data flow — no App Groups

- App writes config + cached quotes via `SharedFileConfig.save()` into the widget's sandbox container.
- Widget reads with `SharedFileConfig.load()` from its own sandboxed home.
- `SharedFileConfig` uses `getpwuid()` to resolve the real home directory and bypass the app sandbox.
- Widget **also** accepts its own configuration via `AppIntentConfigurationIntent` (in-widget settings).
- `UserDefaults.standard` is app-local only; the widget never reads it.

## Key files

| File | Role |
|------|------|
| `Shared/NotionAPI.swift` | Notion HTTP client (API version `2022-06-28`) |
| `Shared/SharedFileConfig.swift` | Sandbox-crossing file bridge — **do not refactor to App Groups** |
| `Shared/QuoteStore.swift` | `UserDefaults`-based cache + `WidgetCenter` timeline reload |
| `Shared/SharedConstants.swift` | Keys, widget kind, refresh interval bounds (min 30 s, default 300 s) |
| `NotionQuotesWidget/NotionQuotesWidget.swift` | Timeline provider, widget views, configuration intent |

## Conventions

- Swift 5.10, no external dependencies (Foundation, SwiftUI, WidgetKit, AppIntents, OSLog only).
- Logging via `Logger` (subsystem `com.jonathanlamela.NotionQuotes`), not `print()`.
- `@MainActor` on the view model; `async/await` for network calls.
- Widget timeline generates up to 60 entries with time-bucket rotation: `bucket = Int(date.timeIntervalSinceReferenceDate) / interval % count`.

## Pitfalls

- **Entitlements**: widget requires `com.apple.security.network.client`; both targets must be signed by the same Apple team.
- **Bundle IDs are paired**: app `com.jonathanlamela.NotionQuotes`, widget `com.jonathanlamela.NotionQuotes.widget`.
- **Config duplication**: users enter Notion credentials in both the app UI and widget settings; they are stored independently.
- **DerivedData**: if the widget doesn't appear after a build, delete `~/Library/Developer/Xcode/DerivedData` and rebuild.
