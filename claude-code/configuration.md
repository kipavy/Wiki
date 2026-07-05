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
claude mcp add github -- npx -y @modelcontextprotocol/server-github
claude mcp list        # see what's connected
```

Project-shared servers can also be committed in a `.mcp.json` at the repo root so your team gets them automatically. Many plugins bundle their own MCP servers, so you often get these without configuring anything.

### Statusline

The line at the bottom of the terminal can show model, git branch, token usage, cost, and more. Set a custom command under `statusLine` in `settings.json`, or use a ready-made tool — see [**ccstatusline**](plugins.md#ccstatusline) on the plugins page for a batteries-included option.

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
}
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
