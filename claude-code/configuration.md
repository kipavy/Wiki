---
description: settings.json, permissions, hooks, MCP servers, statusline, and model choice.
---

# Configuration

Claude Code is configured through `settings.json` files and a few slash commands. You rarely need to touch most of it — but knowing where the knobs are saves a lot of friction, especially permissions and hooks.

### settings.json — where settings live

Like `CLAUDE.md`, settings merge from several files, most-specific-wins:

| File | Scope | Commit it? |
| --- | --- | --- |
| `~/.claude/settings.json` | You, every project | personal |
| `.claude/settings.json` | This project, whole team | ✅ yes |
| `.claude/settings.local.json` | This project, just you | ❌ gitignore it |

The friendliest way to change common settings (theme, model, statusline) is the interactive menu:

```
/config
```

### Permissions — stop the endless prompts

By default Claude asks before running commands or editing files. Once you trust a pattern, allowlist it so you stop getting prompted. Permission rules live under `permissions` with `allow`, `ask`, and `deny` lists:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run test:*)",
      "Bash(git status)",
      "Read(//home/me/project/**)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Read(./.env)"
    ]
  }
}
```

{% hint style="info" %}
The fast way to build an allowlist: when Claude asks permission for something you'll always approve, choose the **"always allow"** option in the prompt — it writes the rule for you. `deny` always wins over `allow`, so use it to fence off secrets and destructive commands.
{% endhint %}

### Hooks — run your own scripts on events

Hooks are the automation layer: shell commands Claude Code runs **automatically** when certain events fire. This is what you reach for when you want "every time X happens, do Y" — because the harness runs it, not Claude, so it's deterministic.

Common events: `PreToolUse` / `PostToolUse` (before/after a tool runs), `UserPromptSubmit`, `Stop`, `SessionStart`.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "npx prettier --write $CLAUDE_FILE_PATHS" }
        ]
      }
    ]
  }
}
```

Typical uses: auto-format after every edit, run tests when a file changes, block edits to protected paths, log every command. Configure them in `settings.json` or via the `/hooks` command.

### MCP servers — give Claude new tools

**MCP** (Model Context Protocol) lets Claude talk to external systems — databases, GitHub, a browser, your own APIs — through standardized tool servers. Add one with:

```bash
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp list        # see what's connected
```

Project-shared servers can also be committed in a `.mcp.json` at the repo root so your team gets them automatically. Many plugins bundle their own MCP servers, so you often get these without configuring anything.

{% hint style="info" %}
Not sure which to add? See [**MCP Servers Worth It**](../ai-agents/mcp-servers.md) for a short, curated list (Context7, GitHub, Playwright, and more).
{% endhint %}

### Statusline

The line at the bottom of the terminal can show model, git branch, token usage, cost, and more. Set a custom command under `statusLine` in `settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
}
```

Rather than script it yourself, use a ready-made tool. Two good ones:

* [**ccstatusline**](plugins.md#ccstatusline) — an interactive TUI that writes the config for you. Batteries-included.
* **ccsa** (`@refinist/ccsa`) — a **visual web editor** at [ccse.refineup.com](https://ccse.refineup.com). Drag together the segments you want — cwd, git branch/changes, node version, model, thinking effort, a context bar, input/cached/output token counts, and session/weekly usage with reset timers — then copy a one-line `npx` command that embeds the whole layout as JSON. Start from a template like [`?tpl=daily-driver`](https://ccse.refineup.com/?tpl=daily-driver) and tweak from there.

My daily-driver ccsa layout — three lines (cwd/git/node · model/thinking/context/tokens · session & weekly usage). Run it once to apply, or drop the command straight into `statusLine.command`:

```bash
npx -y @refinist/ccsa@latest '{"version":3,"lines":[[{"id":"7a0f430e-12bc-40b1-9867-4d6b702c9b0f","type":"current-working-dir","color":"gradient:atlas","rawValue":true,"metadata":{"abbreviateHome":"true"}},{"id":"3231b940-9ead-4135-92f0-f05f6afaf7a0","type":"separator"},{"id":"d8793076-ef92-49aa-b860-77a60d3c71bc","type":"git-branch"},{"id":"e19cdfe2-79a4-47b4-a589-8be36b33673d","type":"separator"},{"id":"c402c97e-41be-4fee-a94d-115e75195760","type":"git-changes"},{"id":"ef030b95-f7f1-4c5d-8679-790e403a4677","type":"separator"},{"id":"40cdc389-0b23-4a65-964c-852a6473bf5c","type":"custom-command","commandPath":"echo \"⬢ $(node -v)\"","color":"gradient:cristal"}],[{"id":"dd-1","type":"model","bold":true,"rawValue":true},{"id":"9fd5eb5a-4c9d-4b69-b6f5-92c664f73f5e","type":"separator"},{"id":"cf22d4a8-304c-47e8-b766-86f32b26173b","type":"thinking-effort","bold":true,"rawValue":true},{"id":"8419e77e-9474-46b8-aab4-3f56987bde8c","type":"separator"},{"id":"438001f2-59df-4a40-971b-5531309d05b2","type":"context-bar","bold":false,"rawValue":true,"metadata":{"display":"progress-short"}},{"id":"1111c67b-92ec-4562-9067-6e8365b012d8","type":"separator"},{"id":"94824f3e-e7b0-4c63-b065-18108b4fdb5e","type":"tokens-input","rawValue":false},{"id":"077404c1-f7a9-4598-a19d-307170a286a0","type":"separator"},{"id":"76ee57f5-0426-4c0d-b4e5-71188baa45b3","type":"tokens-cached","rawValue":false},{"id":"2a2832ac-4ed3-4255-a46f-730be96841ab","type":"separator"},{"id":"013f2328-96aa-48c4-aefa-7243cd9d97b4","type":"tokens-output","rawValue":false}],[{"id":"e3d5f4de-0905-474a-b117-a0f7f4fd7b41","type":"session-usage","rawValue":false,"metadata":{"display":"progress-short","cursor":"true"}},{"id":"c91c50f6-e35f-44f0-a66c-b93f3e74f0ab","type":"separator"},{"id":"259a5f5a-8354-4331-9918-5472dfcfa963","type":"reset-timer","rawValue":true,"metadata":{"display":"time","compact":"true"}},{"id":"bb61a59b-8453-4955-b6c1-48ca61209e22","type":"separator"},{"id":"013869b1-f68e-423f-adbf-624add611280","type":"weekly-usage","rawValue":false,"metadata":{"display":"progress-short","cursor":"true"}},{"id":"63cdb1b2-aac2-48d6-b251-473f017fb1ab","type":"separator"},{"id":"4932c6ee-bc58-4240-8bb5-2087e516e4be","type":"weekly-reset-timer","rawValue":true,"metadata":{"absolute":"false","weekday":"false","compact":"true"}}]],"flexMode":"full","compactThreshold":60,"colorLevel":2,"inheritSeparatorColors":false,"globalBold":false,"gitCacheTtlSeconds":5,"minimalistMode":false,"defaultPaddingSide":"both","powerline":{"enabled":false,"separators":[""],"separatorInvertBackground":[false],"startCaps":[],"endCaps":[],"autoAlign":false,"continueThemeAcrossLines":false}}'
```

### Choosing a model

Switch models mid-session with `/model`, or pin one in settings:

```json
{ "model": "claude-opus-4-8" }
```

Rule of thumb: reach for the most capable model (**Opus**) for hard reasoning, architecture, and gnarly debugging; drop to a faster one for routine edits and boilerplate. `/model` makes it a one-keystroke switch, so change it to fit the task in front of you.

{% hint style="success" %}
Sensible starting point: allowlist your test/lint/build commands, add one `PostToolUse` hook to auto-format, and leave the rest at defaults. Add configuration when something annoys you — not before.
{% endhint %}
