# FrameHero CLI

Automate App Store screenshot capture across multiple locales with a single command.

## Install

```bash
brew tap gunnargray-dev/tap && brew install framehero
```

Or from source:

```bash
git clone https://github.com/gunnargray-dev/FrameHero.git
cd FrameHero
swift build -c release
cp .build/release/framehero /usr/local/bin/
```

## Requirements

- macOS 14+, Xcode 15+ with Simulator installed
- A booted iOS Simulator (`xcrun simctl boot "iPhone 16 Pro Max"`)
- **Accessibility permission** for your terminal app — required for `tap` and `navigate` actions.
  Grant access in **System Settings > Privacy & Security > Accessibility** for Terminal, iTerm2, Warp, or whichever terminal you use. `framehero` will check this before capture and show a clear error if missing.

## Quick Start

```bash
# 1. Discover your app's screens
framehero init --bundle-id com.myapp --scheme MyApp

# 2. Capture across locales
framehero capture
```

## Config File

`framehero.yml` defines what to capture:

```yaml
app:
  bundle-id: com.myapp
  scheme: MyApp
  simulator: iPhone 16 Pro Max

screens:
  - name: Home
    action: launch
  - name: Search
    action: tap "Search"
  - name: Settings
    action: navigate "Profile" > "Settings"

locales:
  - en-US
  - de-DE
  - ja-JP

output: ./captures
project: MyApp
```

### Actions

| Action | Example | Description |
|--------|---------|-------------|
| `launch` | `launch` | Capture the launch screen |
| `tap` | `tap "Search"` | Tap an element by accessibility label |
| `navigate` | `navigate "A" > "B"` | Sequential taps with 1s wait between |

## Commands

### `framehero init`

Discovers your app's screens and generates `framehero.yml`.

```bash
framehero init --bundle-id com.myapp --scheme MyApp
```

| Flag | Default | Description |
|------|---------|-------------|
| `--bundle-id` | required | App bundle identifier |
| `--scheme` | required | Xcode scheme name |
| `--simulator` | iPhone 16 Pro Max | Simulator device |
| `--output` | ./framehero.yml | Config file path |

### `framehero capture`

Captures screenshots across all locales defined in the config.

```bash
framehero capture
framehero capture --config ./my.yml --output ./shots --locales de-DE,ja-JP
```

| Flag | Default | Description |
|------|---------|-------------|
| `--config` | ./framehero.yml | Config file path |
| `--output` | ./captures | Output directory |
| `--locales` | from config | Override locales |
| `--simulator` | from config | Override simulator |
| `--project` | app name | FrameHero project name |
| `--no-import` | false | Skip FrameHero import |
| `--format` | auto | Output format: text or json |

## AI Agent Usage

AI agents (Claude Code, Codex) can write `framehero.yml` directly by reading your source code, then run `framehero capture`. No interactive setup needed.

## FrameHero Integration

If [FrameHero.app](https://framehero.dev) is installed, captured screenshots are automatically imported into a project with device frames applied. Open FrameHero to edit, add text overlays, and export.

## Output

**Terminal:**
```
Capturing 3 screens in 3 locales on iPhone 16 Pro Max

  ✓ en-US: Home, Search, Settings (3 screenshots)
  ✓ de-DE: Home, Search, Settings (3 screenshots)
  ✓ ja-JP: Home, Search, Settings (3 screenshots)

9 screenshots saved to ./captures
Imported into FrameHero project "MyApp"
```

**CI/piped (JSON lines):**
```json
{"locale":"en-US","screens":["Home","Search","Settings"],"count":3,"status":"ok"}
{"locale":"de-DE","screens":["Home","Search","Settings"],"count":3,"status":"ok"}
{"locale":"ja-JP","screens":["Home","Search","Settings"],"count":3,"status":"ok"}
{"total":9,"output":"./captures","project":"MyApp","imported":true}
```

## Troubleshooting

**"Accessibility permission required"** — `tap` and `navigate` actions use macOS Accessibility to interact with the Simulator window. Go to System Settings > Privacy & Security > Accessibility and add your terminal app.

**Navigation not working** — Make sure the Simulator is visible on screen (not minimized) and the app is launched. The screen names in `framehero.yml` should match the order of sidebar items or tab bar items in your app.

**Wrong screenshots** — `framehero` relaunches your app before each screen capture. If your app restores navigation state on launch, the initial screen may not be the root view. Consider resetting state on launch or using `launch` for the first screen only.

## License

MIT
