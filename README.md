# FrameHero CLI

Automate App Store screenshot capture across multiple locales with a single command.

## Requirements

- macOS 14+, Xcode 15+ with Simulator installed
- A booted iOS Simulator (`xcrun simctl boot "iPhone 16 Pro Max"`)
- Your app installed on the simulator (build & run from Xcode first)
- **Accessibility permission** for your terminal app — required for `framehero init` screen discovery.
  Grant access in **System Settings > Privacy & Security > Accessibility**.

## Install

```bash
brew tap gunnargray-dev/tap && brew install framehero
```

Or from source:

```bash
git clone https://github.com/gunnargray-dev/framehero-cli.git
cd framehero-cli
swift build -c release
cp .build/release/framehero /usr/local/bin/
```

## Quick Start

```bash
# 1. Generate a config file
framehero init --bundle-id com.myapp --scheme MyApp

# 2. Edit framehero.yml if needed, then capture
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

Works in two modes:
- **Interactive** (terminal): shows discovered screens, prompts for selection and locales
- **Non-interactive** (AI agent / CI): includes all discovered screens with defaults, prints config path

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

For screens with `tap` or `navigate` actions, `framehero` generates and runs an XCUITest to interact with your app. For `launch`-only configs, it uses `simctl` directly (faster, no Xcode build step).

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

AI agents (Claude Code, Codex) can use `framehero` in two ways:

1. **Run `framehero init`** non-interactively to generate a starter config, then edit it
2. **Write `framehero.yml` directly** by reading your source code, then run `framehero capture`

No interactive setup needed. The generated config includes comments explaining each field.

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

**"No simulator booted"** — Boot a simulator first: `xcrun simctl boot "iPhone 16 Pro Max"`

**"App not found on simulator"** — Build and run your app from Xcode at least once so it's installed on the simulator.

**"Xcode Command Line Tools required"** — Run `xcode-select --install`.

**"XCUITest failed: Could not find element"** — The accessibility label in your config doesn't match an element in your app. Check labels using Xcode's Accessibility Inspector.

**"Accessibility permission required"** — `framehero init` uses macOS Accessibility to discover screens. Go to System Settings > Privacy & Security > Accessibility and add your terminal app.

**Wrong simulator used** — If the config specifies a simulator that isn't booted, `framehero` uses whichever simulator is booted and prints a warning. Boot the right one or update your config.

## License

MIT
