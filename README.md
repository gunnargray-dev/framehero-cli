# FrameHero CLI

Automate App Store screenshots from the command line. One config file. One command. Every screen, every locale, with device frames.

```bash
framehero capture
```

- Captures screenshots across your app's screens automatically using XCUITest
- Supports multiple locales in a single run
- Wraps screenshots in pixel-perfect device frames (iPhone, iPad)
- Works with any app layout — tab bars, sidebars, navigation stacks
- No test targets or XCUITest setup required in your project
- AI-agent friendly — fully non-interactive, config-driven

## Install

```bash
brew tap gunnargray-dev/tap && brew install framehero
```

Or build from source:

```bash
git clone https://github.com/gunnargray-dev/framehero-cli.git
cd framehero-cli
swift build -c release
cp .build/release/framehero /usr/local/bin/
cp -R .build/arm64-apple-macosx/release/framehero-cli_framehero.bundle /usr/local/bin/
```

**Requirements:** macOS 14+, Xcode 15+ with Simulator installed.

## Quick Start

```bash
# 1. Boot a simulator and install your app (build & run from Xcode)
xcrun simctl boot "iPhone 16 Pro Max"

# 2. Generate a config file
framehero init --bundle-id com.myapp --scheme MyApp

# 3. Capture screenshots
framehero capture
```

That's it. Screenshots are saved to `./captures/`, organized by locale.

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
frame: auto
```

### Actions

| Action | Example | Description |
|--------|---------|-------------|
| `launch` | `launch` | Capture the initial screen |
| `tap` | `tap "Search"` | Tap an element by its visible UI label |
| `navigate` | `navigate "A" > "B"` | Sequential taps with a pause between each |
| `scroll` | `scroll down` | Scroll the view (up, down, left, right) |
| `swipe` | `swipe left` | Swipe gesture (up, down, left, right) |
| `dismiss` | `dismiss` | Dismiss alerts and modals |

Labels must match the **text visible in the UI** — not Swift type names or variable names. Use the text from `Label("Map", ...)`, `Text("Settings")`, `.navigationTitle("Profile")`, or `.accessibilityLabel("Search")`.

If elements are inside a sidebar or behind a back button, the CLI handles that automatically.

### Setup Steps

Run steps before each screen capture (e.g. dismiss onboarding or permission dialogs):

```yaml
setup:
  - dismiss
  - tap "Skip"
```

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

**Note:** Screen discovery requires **Accessibility permission** for your terminal app. Grant access in System Settings > Privacy & Security > Accessibility.

### `framehero capture`

Captures screenshots across all screens and locales defined in the config.

```bash
framehero capture
framehero capture --config ./my.yml --output ./shots --locales de-DE,ja-JP
framehero capture --frame auto --frame-color black-titanium
```

| Flag | Default | Description |
|------|---------|-------------|
| `--config` | ./framehero.yml | Config file path |
| `--output` | ./captures | Output directory |
| `--locales` | from config | Override locales |
| `--simulator` | from config | Override simulator |
| `--frame` | from config | Device frame: device name, `auto`, or `none` |
| `--frame-color` | default | Frame color variant (e.g. `black-titanium`) |
| `--no-import` | false | Skip FrameHero app import |
| `--format` | auto | Output format: `text` or `json` |

For screens with `tap` or `navigate` actions, FrameHero generates and runs an XCUITest automatically. For `launch`-only configs, it uses `simctl` directly (faster, no Xcode build step).

## Device Frames

Screenshots can be wrapped in pixel-perfect device bezels. Both raw and framed versions are saved:

```
captures/en-US/
  Home.png              # raw screenshot
  Home_framed.png       # with device frame
```

**Supported devices:** iPhone 16, iPhone 16 Plus, iPhone 16 Pro, iPhone 16 Pro Max, iPad Pro 11", iPad Pro 13"

**Color variants:** Natural Titanium (default), Black Titanium (Pro/Pro Max only)

Set `frame: auto` in your config to match the simulator device, or specify a device name directly. iPhone 17 models automatically use the matching iPhone 16 frame (same form factor).

## Finish with FrameHero

The CLI captures your screenshots and wraps them in device frames — but App Store listings need more. Promotional text, backgrounds, localized copy, and pixel-perfect layouts across every device size.

**[FrameHero](https://framehero.dev)** picks up where the CLI leaves off:

- Add text overlays with localized copy
- Design with custom backgrounds and gradients
- Sync layout templates across all locales at once
- Export directly to App Store Connect specs

If FrameHero is installed, `framehero capture` automatically imports your screenshots into a project. Open the app and they're ready to design — no manual file wrangling.

**Capture with the CLI. Finish with the app. Ship to the App Store.**

[Get FrameHero](https://framehero.dev)

## AI Agent Usage

### MCP Server

Add FrameHero as a native tool for AI coding agents — no shell commands needed.

**Claude Code:**
```bash
claude mcp add framehero -- npx github:gunnargray-dev/framehero-cli/mcp-server
```

**Cursor** — add to `.cursor/mcp.json`:
```json
{
  "mcpServers": {
    "framehero": {
      "command": "npx",
      "args": ["github:gunnargray-dev/framehero-cli/mcp-server"]
    }
  }
}
```

This exposes three tools: `framehero_write_config`, `framehero_capture`, and `framehero_list_devices`.

### Direct CLI Usage

AI agents can also use the CLI directly:

1. Read the project's SwiftUI views to identify screens and navigation labels
2. Write `framehero.yml` with the correct bundle ID, scheme, and screen actions
3. Run `framehero capture`

## Troubleshooting

| Error | Fix |
|-------|-----|
| No simulator booted | `xcrun simctl boot "iPhone 16 Pro Max"` |
| App not found on simulator | Build and run your app from Xcode first |
| Xcode Command Line Tools required | `xcode-select --install` |
| Could not find element | The label doesn't match UI text. Check `Label()`, `Text()`, `.accessibilityLabel()` in your source code |
| Device not supported | Check supported devices in the Device Frames section |
| Accessibility permission required | System Settings > Privacy & Security > Accessibility > add your terminal app |
| Wrong simulator used | Boot the correct simulator or update your config |

## License

MIT
