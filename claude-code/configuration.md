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
npx -y @refinist/ccsa@latest eyJ2ZXJzaW9uIjozLCJsaW5lcyI6W1t7ImlkIjoiN2EwZjQzMGUtMTJiYy00MGIxLTk4NjctNGQ2YjcwMmM5YjBmIiwidHlwZSI6ImN1cnJlbnQtd29ya2luZy1kaXIiLCJjb2xvciI6ImdyYWRpZW50OmF0bGFzIiwicmF3VmFsdWUiOnRydWUsIm1ldGFkYXRhIjp7ImFiYnJldmlhdGVIb21lIjoidHJ1ZSJ9fSx7ImlkIjoiMzIzMWI5NDAtOWVhZC00MTM1LTkyZjAtZjA1ZjZhZmFmN2EwIiwidHlwZSI6InNlcGFyYXRvciJ9LHsiaWQiOiJkODc5MzA3Ni1lZjkyLTQ5YWEtYjg2MC03N2E2MGQzYzcxYmMiLCJ0eXBlIjoiZ2l0LWJyYW5jaCJ9LHsiaWQiOiJlMTljZGZlMi03OWE0LTQ3YjQtYTU4OS04YmUzNmIzMzY3M2QiLCJ0eXBlIjoic2VwYXJhdG9yIn0seyJpZCI6ImM0MDJjOTdlLTQxYmUtNGZlZS1hOTRkLTExNWU3NTE5NTc2MCIsInR5cGUiOiJnaXQtY2hhbmdlcyJ9LHsiaWQiOiJlZjAzMGI5NS1mN2YxLTRjNWQtODY3OS03OTBlNDAzYTQ2NzciLCJ0eXBlIjoic2VwYXJhdG9yIn0seyJpZCI6IjQwY2RjMzg5LTBiMjMtNGE2NS05NjRjLTg1MmE2NDczYmY1YyIsInR5cGUiOiJjdXN0b20tY29tbWFuZCIsImNvbW1hbmRQYXRoIjoiZWNobyBcIuKsoiAkKG5vZGUgLXYpXCIiLCJjb2xvciI6ImdyYWRpZW50OmNyaXN0YWwifV0sW3siaWQiOiJkZC0xIiwidHlwZSI6Im1vZGVsIiwiYm9sZCI6dHJ1ZSwicmF3VmFsdWUiOnRydWV9LHsiaWQiOiI5ZmQ1ZWI1YS00YzlkLTRiNjktYjZmNS05MmM2NjRmNzNmNWUiLCJ0eXBlIjoic2VwYXJhdG9yIn0seyJpZCI6ImNmMjJkNGE4LTMwNGMtNDdlOC1iNzY2LTg2ZjMyYjI2MTczYiIsInR5cGUiOiJ0aGlua2luZy1lZmZvcnQiLCJib2xkIjp0cnVlLCJyYXdWYWx1ZSI6dHJ1ZX0seyJpZCI6Ijg0MTllNzdlLTk0NzQtNDZiOC1hYWI0LTNmNTY5ODdiZGU4YyIsInR5cGUiOiJzZXBhcmF0b3IifSx7ImlkIjoiNDM4MDAxZjItNTlkZi00YTQwLTk3MWItNTUzMTMwOWQwNWIyIiwidHlwZSI6ImNvbnRleHQtYmFyIiwiYm9sZCI6ZmFsc2UsInJhd1ZhbHVlIjp0cnVlLCJtZXRhZGF0YSI6eyJkaXNwbGF5IjoicHJvZ3Jlc3Mtc2hvcnQifX0seyJpZCI6IjExMTFjNjdiLTkyZWMtNDU2Mi05MDY3LTZlODM2NWIwMTJkOCIsInR5cGUiOiJzZXBhcmF0b3IifSx7ImlkIjoiOTQ4MjRmM2UtZTdiMC00YzYzLWIwNjUtMTgxMDhiNGZkYjVlIiwidHlwZSI6InRva2Vucy1pbnB1dCIsInJhd1ZhbHVlIjpmYWxzZX0seyJpZCI6IjA3NzQwNGMxLWY3YTktNDU5OC1hMTlkLTMwNzE3MGEyODZhMCIsInR5cGUiOiJzZXBhcmF0b3IifSx7ImlkIjoiNzZlZTU3ZjUtMDQyNi00YzBkLWI0ZTUtNzExODhiYWE0NWIzIiwidHlwZSI6InRva2Vucy1jYWNoZWQiLCJyYXdWYWx1ZSI6ZmFsc2V9LHsiaWQiOiIyYTI4MzJhYy00ZWQzLTQyNTUtYTQ2Zi03MzBiZTk2ODQxYWIiLCJ0eXBlIjoic2VwYXJhdG9yIn0seyJpZCI6IjAxM2YyMzI4LTk2YWEtNDhjNC1hZWZhLTcyNDNjZDlkOTdiNCIsInR5cGUiOiJ0b2tlbnMtb3V0cHV0IiwicmF3VmFsdWUiOmZhbHNlfV0sW3siaWQiOiJlM2Q1ZjRkZS0wOTA1LTQ3NGEtYjExNy1hMGY3ZjRmZDdiNDEiLCJ0eXBlIjoic2Vzc2lvbi11c2FnZSIsInJhd1ZhbHVlIjpmYWxzZSwibWV0YWRhdGEiOnsiZGlzcGxheSI6InByb2dyZXNzLXNob3J0IiwiY3Vyc29yIjoidHJ1ZSJ9fSx7ImlkIjoiYzkxYzUwZjYtZTM1Zi00NGYwLWE2NmMtYjkzZjNlNzRmMGFiIiwidHlwZSI6InNlcGFyYXRvciJ9LHsiaWQiOiIyNTlhNWY1YS04MzU0LTQzMzEtOTkxOC01NDcyZGZjZmE5NjMiLCJ0eXBlIjoicmVzZXQtdGltZXIiLCJyYXdWYWx1ZSI6dHJ1ZSwibWV0YWRhdGEiOnsiZGlzcGxheSI6InRpbWUiLCJjb21wYWN0IjoidHJ1ZSJ9fSx7ImlkIjoiYmI2MWE1OWItODQ1My00OTU1LWI2YzEtNDhjYTYxMjA5ZTIyIiwidHlwZSI6InNlcGFyYXRvciJ9LHsiaWQiOiIwMTM4NjliMS1mNjhlLTQyM2YtYWRiZi02MjRhZGQ2MTEyODAiLCJ0eXBlIjoid2Vla2x5LXVzYWdlIiwicmF3VmFsdWUiOmZhbHNlLCJtZXRhZGF0YSI6eyJkaXNwbGF5IjoicHJvZ3Jlc3Mtc2hvcnQiLCJjdXJzb3IiOiJ0cnVlIn19LHsiaWQiOiI2M2NkYjFiMi1hYWMyLTQ4ZDYtYjI1MS00NzNmMDE3ZmIxYWIiLCJ0eXBlIjoic2VwYXJhdG9yIn0seyJpZCI6IjQ5MzJjNmVlLWJjNTgtNDI0MC04YmI1LTIwODdlNTE2ZTRiZSIsInR5cGUiOiJ3ZWVrbHktcmVzZXQtdGltZXIiLCJyYXdWYWx1ZSI6dHJ1ZSwibWV0YWRhdGEiOnsiYWJzb2x1dGUiOiJmYWxzZSIsIndlZWtkYXkiOiJmYWxzZSIsImNvbXBhY3QiOiJ0cnVlIn19XV0sImZsZXhNb2RlIjoiZnVsbCIsImNvbXBhY3RUaHJlc2hvbGQiOjYwLCJjb2xvckxldmVsIjoyLCJpbmhlcml0U2VwYXJhdG9yQ29sb3JzIjpmYWxzZSwiZ2xvYmFsQm9sZCI6ZmFsc2UsImdpdENhY2hlVHRsU2Vjb25kcyI6NSwibWluaW1hbGlzdE1vZGUiOmZhbHNlLCJkZWZhdWx0UGFkZGluZ1NpZGUiOiJib3RoIiwicG93ZXJsaW5lIjp7ImVuYWJsZWQiOmZhbHNlLCJzZXBhcmF0b3JzIjpbIiJdLCJzZXBhcmF0b3JJbnZlcnRCYWNrZ3JvdW5kIjpbZmFsc2VdLCJzdGFydENhcHMiOltdLCJlbmRDYXBzIjpbXSwiYXV0b0FsaWduIjpmYWxzZSwiY29udGludWVUaGVtZUFjcm9zc0xpbmVzIjpmYWxzZX19
```

{% hint style="warning" %}
`ccsa` also accepts a raw JSON string (`ccsa '{"version":3,...}'`), which is what the web editor gives you by default. Don't use that form on Windows: both `cmd.exe` and PowerShell strip the embedded `"` characters when forwarding the argument to the native `npx`/`node` process, silently turning valid JSON into malformed JSON. It only survives intact in a POSIX shell (Git Bash, WSL, macOS/Linux). The base64 form above has no shell-special characters, so it works identically in `cmd.exe`, PowerShell, and Git Bash — always regenerate a base64 argument for any config you paste into a Windows terminal.
{% endhint %}

### Choosing a model

Switch models mid-session with `/model`, or pin one in settings:

```json
{ "model": "claude-opus-4-8" }
```

Rule of thumb: reach for the most capable model (**Opus**) for hard reasoning, architecture, and gnarly debugging; drop to a faster one for routine edits and boilerplate. `/model` makes it a one-keystroke switch, so change it to fit the task in front of you.

{% hint style="success" %}
Sensible starting point: allowlist your test/lint/build commands, add one `PostToolUse` hook to auto-format, and leave the rest at defaults. Add configuration when something annoys you — not before.
{% endhint %}
