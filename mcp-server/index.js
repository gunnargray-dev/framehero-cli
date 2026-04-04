#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "child_process";
import { promisify } from "util";
import { existsSync } from "fs";
import { readFile, writeFile, mkdir } from "fs/promises";
import { dirname } from "path";

const exec = promisify(execFile);

// Find framehero binary
function findFramehero() {
  const paths = [
    "/usr/local/bin/framehero",
    "/opt/homebrew/bin/framehero",
    `${process.env.HOME}/.local/bin/framehero`,
  ];
  for (const p of paths) {
    if (existsSync(p)) return p;
  }
  return "framehero"; // hope it's in PATH
}

const FRAMEHERO = findFramehero();

async function runFramehero(args, cwd) {
  try {
    const { stdout, stderr } = await exec(FRAMEHERO, args, {
      cwd,
      timeout: 600000,
    });
    return { stdout, stderr, exitCode: 0 };
  } catch (err) {
    return {
      stdout: err.stdout || "",
      stderr: err.stderr || err.message,
      exitCode: err.code || 1,
    };
  }
}

const server = new McpServer({
  name: "framehero",
  version: "1.0.0",
});

// --- Tools ---

server.tool(
  "framehero_write_config",
  "Write a framehero.yml config file for capturing App Store screenshots. Read the app's SwiftUI source code first to find screen labels — use the text from Label(), Text(), .accessibilityLabel(), not Swift type names.",
  {
    path: z
      .string()
      .default("./framehero.yml")
      .describe("Path to write the config file"),
    bundle_id: z.string().describe("App bundle identifier (from Info.plist or .pbxproj)"),
    scheme: z.string().describe("Xcode scheme name"),
    screens: z
      .array(
        z.object({
          name: z.string().describe("Screen name for the output filename"),
          action: z
            .string()
            .describe(
              'Action: "launch", \'tap "Label"\', or \'navigate "A" > "B"\'. Labels must match UI text visible to XCUITest.'
            ),
        })
      )
      .describe("Screens to capture"),
    locales: z
      .array(z.string())
      .default(["en-US"])
      .describe("BCP 47 locale codes"),
    frame: z
      .string()
      .optional()
      .describe('"auto" (match simulator), device name, or "none"'),
    frame_color: z
      .string()
      .optional()
      .describe('Frame color variant (e.g. "black-titanium")'),
    simulator: z.string().optional().describe("Simulator device name"),
  },
  async ({ path, bundle_id, scheme, screens, locales, frame, frame_color, simulator }) => {
    let yaml = `# App to capture\napp:\n  bundle-id: ${bundle_id}\n  scheme: ${scheme}\n`;
    if (simulator) yaml += `  simulator: ${simulator}\n`;

    yaml += `\n# Screens to capture\n# Actions: launch, tap "Label", navigate "A" > "B"\nscreens:\n`;
    for (const s of screens) {
      yaml += `  - name: ${s.name}\n    action: ${s.action}\n`;
    }

    yaml += `\n# Locales to capture (BCP 47 codes)\nlocales:\n`;
    for (const l of locales) {
      yaml += `  - ${l}\n`;
    }

    yaml += `\noutput: ./captures\n`;

    if (frame) {
      yaml += `\n# Device frame\nframe: ${frame}\n`;
    }

    await mkdir(dirname(path), { recursive: true }).catch(() => {});
    await writeFile(path, yaml);

    return {
      content: [
        {
          type: "text",
          text: `Config written to ${path}\n\nRun framehero_capture to capture screenshots.`,
        },
      ],
    };
  }
);

server.tool(
  "framehero_capture",
  "Capture App Store screenshots for an iOS app. Requires a booted simulator with the app installed. Generates XCUITest automatically for screen navigation — no test setup needed in the project.",
  {
    config: z
      .string()
      .default("./framehero.yml")
      .describe("Path to framehero.yml config file"),
    output: z.string().optional().describe("Output directory for screenshots"),
    locales: z
      .string()
      .optional()
      .describe("Override locales (comma-separated)"),
    simulator: z.string().optional().describe("Override simulator device"),
    frame: z
      .string()
      .optional()
      .describe('Device frame: "auto", device name, or "none"'),
    frame_color: z
      .string()
      .optional()
      .describe('Frame color variant (e.g. "black-titanium")'),
  },
  async ({ config, output, locales, simulator, frame, frame_color }) => {
    const args = ["capture", "--config", config, "--format", "json", "--no-import"];
    if (output) args.push("--output", output);
    if (locales) args.push("--locales", locales);
    if (simulator) args.push("--simulator", simulator);
    if (frame) args.push("--frame", frame);
    if (frame_color) args.push("--frame-color", frame_color);

    const cwd = dirname(config);
    const result = await runFramehero(args, cwd === "." ? process.cwd() : cwd);

    if (result.exitCode !== 0) {
      return {
        content: [
          {
            type: "text",
            text: `Capture failed (exit ${result.exitCode}):\n${result.stderr}`,
          },
        ],
        isError: true,
      };
    }

    // Parse JSON lines output
    const lines = result.stdout
      .trim()
      .split("\n")
      .filter((l) => l.startsWith("{"));
    const results = lines.map((l) => {
      try {
        return JSON.parse(l);
      } catch {
        return null;
      }
    }).filter(Boolean);

    const summary = results.find((r) => r.total !== undefined);
    const localeResults = results.filter((r) => r.locale);

    let text = "";
    for (const lr of localeResults) {
      text += `${lr.locale}: ${lr.screens?.join(", ")} (${lr.count} screenshots) — ${lr.status}\n`;
    }
    if (summary) {
      text += `\n${summary.total} screenshots saved to ${summary.output}`;
    }

    return {
      content: [{ type: "text", text }],
    };
  }
);

server.tool(
  "framehero_list_devices",
  "List booted simulators and supported device frames for App Store screenshot capture.",
  {},
  async () => {
    // Get booted simulators
    let booted = "No simulators booted";
    try {
      const { stdout } = await exec("xcrun", [
        "simctl",
        "list",
        "devices",
        "booted",
      ]);
      const lines = stdout.split("\n").filter((l) => l.includes("(Booted)"));
      if (lines.length > 0) {
        booted = lines.map((l) => l.trim().replace(/\s*\(.*/, "")).join("\n");
      }
    } catch {}

    const frames = [
      "iPhone 16",
      "iPhone 16 Plus",
      "iPhone 16 Pro (Natural Titanium, Black Titanium)",
      "iPhone 16 Pro Max (Natural Titanium, Black Titanium)",
      "iPad Pro 11\"",
      "iPad Pro 13\"",
    ];

    return {
      content: [
        {
          type: "text",
          text: `Booted simulators:\n${booted}\n\nSupported device frames:\n${frames.join("\n")}\n\niPhone 17 models automatically use matching iPhone 16 frames.`,
        },
      ],
    };
  }
);

// --- Start ---

const transport = new StdioServerTransport();
await server.connect(transport);
