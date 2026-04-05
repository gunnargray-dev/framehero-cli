# FrameHero MCP Server

MCP server for [FrameHero CLI](https://github.com/gunnargray-dev/framehero-cli) — lets AI agents capture App Store screenshots as a native tool.

## Setup

### Prerequisites

Install the FrameHero CLI first:

```bash
brew tap gunnargray-dev/tap && brew install framehero
```

### Claude Code

```bash
claude mcp add framehero -- npx github:gunnargray-dev/framehero-mcp-server
```

### Cursor

Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "framehero": {
      "command": "npx",
      "args": ["github:gunnargray-dev/framehero-mcp-server"]
    }
  }
}
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "framehero": {
      "command": "npx",
      "args": ["github:gunnargray-dev/framehero-mcp-server"]
    }
  }
}
```

## Tools

### `framehero_write_config`

Write a `framehero.yml` config file. The agent reads the app's source code to find screen names and navigation labels, then calls this tool to generate the config.

**Parameters:**
- `bundle_id` (required) — App bundle identifier
- `scheme` (required) — Xcode scheme name
- `screens` (required) — Array of `{ name, action }` objects
- `locales` — Array of BCP 47 codes (default: `["en-US"]`)
- `frame` — Device frame: `"auto"`, `"none"`, or device name
- `frame_color` — Frame color variant (e.g. `"black-titanium"`)
- `path` — Config file path (default: `./framehero.yml`)

### `framehero_capture`

Capture screenshots using a `framehero.yml` config. Runs XCUITest automatically for screen navigation — no test setup needed.

**Parameters:**
- `config` — Path to config file (default: `./framehero.yml`)
- `output` — Output directory
- `locales` — Override locales (comma-separated)
- `simulator` — Override simulator device
- `frame` — Device frame override
- `frame_color` — Frame color variant

### `framehero_list_devices`

List booted simulators and supported device frames.

## How it works

The MCP server is a thin wrapper around the `framehero` CLI binary. It calls `framehero capture --format json` and parses the output. The CLI handles all the heavy lifting: XCUITest generation, simulator interaction, and device frame compositing.
