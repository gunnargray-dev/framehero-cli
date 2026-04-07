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
cp -R .build/arm64-apple-macosx/release/framehero-cli_framehero.bundle /usr/local/bin/
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

# Device frame: "auto" (match simulator), device name, or "none"
frame: auto
```

### Screen Labels

The labels in `tap` and `navigate` actions must match the **text visible in the UI** — not Swift type names or variable names. These are what XCUITest uses to find and tap elements.

**Where to find labels in SwiftUI code:**

| Code pattern | Label to use |
|---|---|
| `Label("Map", systemImage: "map")` | `"Map"` |
| `Text("Settings")` on a button | `"Settings"` |
| `.navigationTitle("Profile")` | `"Profile"` |
| `.accessibilityLabel("Search")` | `"Search"` |

**What does NOT work:**
- Swift type names (`CollectionsView`, `HomeScreen`)
- SF Symbol names (`book.closed`, `magnifyingglass`)
- Enum cases (`NavigationOptions.collections`)
- Variable names (`searchButton`, `settingsTab`)

### Actions

| Action | Example | Description |
|--------|---------|-------------|
| `launch` | `launch` | Capture the launch screen |
| `tap` | `tap "Search"` | Tap an element by its UI label |
| `navigate` | `navigate "A" > "B"` | Sequential taps with 1s wait between |

If elements are inside a sidebar or behind a back button, the CLI handles that automatically.

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
framehero capture --frame auto --frame-color black-titanium
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
| `--frame` | from config | Device frame: device name, `auto`, or `none` |
| `--frame-color` | default | Frame color variant (e.g. `black-titanium`) |

### Device Frames

Screenshots can be wrapped in device bezels. Both raw and framed versions are saved:

```
captures/en-US/
  Home.png              # raw screenshot
  Home_framed.png       # with device frame
```

**Supported devices:** iPhone 16, iPhone 16 Plus, iPhone 16 Pro, iPhone 16 Pro Max, iPad Pro 11", iPad Pro 13"

**Color variants:** Natural Titanium (default), Black Titanium (Pro/Pro Max only)

iPhone 17 models automatically use the matching iPhone 16 frame (same form factor).

## AI Agent Usage

### MCP Server (Claude Code, Cursor)

Add FrameHero as a native tool — agents can capture screenshots without shell commands:

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

### CLI Usage

AI agents can also use the CLI directly — write `framehero.yml` by reading your source code, then run `framehero capture`. No interactive setup needed.

**Agent instructions:**

1. Read the project's SwiftUI views to identify screens and navigation structure
2. Find the UI labels for each screen — look for `Label()`, `Text()`, `.accessibilityLabel()`, and `navigationTitle()` in the source code. Use the **text string**, not the Swift type or variable name
3. Write `framehero.yml` with the correct bundle ID, scheme, screen names, and actions
4. Run `framehero capture`

## From Capture to App Store

The CLI gives you raw screenshots and device-framed versions — but App Store screenshots usually need more: promotional text, backgrounds, and localized copy. That's what [FrameHero](https://framehero.dev) is for.

**What the CLI produces:**

```
captures/en-US/
  Home.png              # raw simulator screenshot
  Home_framed.png       # screenshot inside device bezel
```

**What FrameHero.app adds:**

- Text overlays with localized copy
- Custom backgrounds and gradients
- Layout templates synced across locales
- Direct export to App Store Connect specs

If FrameHero.app is installed, `framehero capture` automatically imports screenshots into a project — open the app and they're ready to design. No manual file wrangling.

**CLI output:**
```
Capturing 3 screens in 3 locales on iPhone 16 Pro Max

  ✓ en-US: Home, Search, Settings (3 screenshots)
  ✓ de-DE: Home, Search, Settings (3 screenshots)
  ✓ ja-JP: Home, Search, Settings (3 screenshots)
  Applying iPhone 16 Pro Max device frame...

9 screenshots captured across 3 locales
Add text overlays and export for App Store → framehero.dev
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

**"Could not find element"** — The label in your config doesn't match the UI text. Read the source code for `Label()`, `Text()`, or `.accessibilityLabel()` values — use the text string, not the Swift type name.

**"Device not supported"** — The `--frame` device name doesn't match a bundled frame. Check supported devices above.

**"Accessibility permission required"** — `framehero init` uses macOS Accessibility to discover screens. Go to System Settings > Privacy & Security > Accessibility and add your terminal app.

**Wrong simulator used** — If the config specifies a simulator that isn't booted, `framehero` uses whichever simulator is booted and prints a warning. Boot the right one or update your config.

## License

MIT
