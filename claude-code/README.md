---
icon: robot
description: Anthropic's terminal coding agent — install it, drive it well, and configure it.
---

# Claude Code

**Claude Code** is Anthropic's coding agent that lives in your terminal. You describe a task in plain language; it reads your code, edits files, runs commands, and iterates — all with your approval. Think of it as a pair-programmer that can actually touch the repo, not just a chat window.

{% hint style="info" %}
New here? Read the pages in order: install below, then **Using It Well** for the habits that separate good output from frustrating output. The rest you can dip into as needed.
{% endhint %}

### In this section

* [Using It Well](using-it-well.md) — the workflow habits that actually matter: plan first, keep tasks small, `/clear` often, let it verify itself.
* [CLAUDE.md](claude-md.md) — the project memory file Claude reads on every session. The single highest-leverage thing to set up.
* [Configuration](configuration.md) — `settings.json`, permissions, hooks, MCP servers, statusline, model choice.
* [Plugins Worth It](plugins.md) — the plugin/marketplace system, plus a curated list of plugins I actually keep installed.
* [Other Agents](../ai-agents/other-agents.md) — Claude Code isn't the only game in town. The worthwhile alternatives, including ones with free models.

### Installing

The **native installer** is the recommended path (self-contained binary, auto-updates in the background). **npm** is the nice cross-platform fallback if you already live in Node land.

{% tabs %}
{% tab title="Native (recommended)" %}
**macOS / Linux / WSL:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://claude.ai/install.ps1 | iex
```

Native installs update themselves in the background — nothing to maintain.
{% endtab %}

{% tab title="npm" %}
Cross-platform, needs **Node.js 22+**:

```bash
npm install -g @anthropic-ai/claude-code
```

{% hint style="warning" %}
Never use `sudo npm install -g` — it causes permission and security headaches. Upgrade with `npm install -g @anthropic-ai/claude-code@latest` (not `npm update -g`).
{% endhint %}

The npm package just pulls the same native binary — `claude` doesn't run on Node at runtime.
{% endtab %}

{% tab title="Homebrew" %}
```bash
brew install --cask claude-code
```

Homebrew installs **don't** auto-update — run `brew upgrade claude-code` yourself. Use the `claude-code@latest` cask if you want new releases the day they ship.
{% endtab %}

{% tab title="Windows (WinGet)" %}
```powershell
winget install Anthropic.ClaudeCode
```

Doesn't auto-update — run `winget upgrade Anthropic.ClaudeCode` now and then. Installing [Git for Windows](https://git-scm.com/downloads/win) is recommended so Claude Code gets a proper Bash tool.
{% endtab %}
{% endtabs %}

Prefer a GUI? There's also a [desktop app](https://code.claude.com/docs/en/desktop-quickstart) and VS Code / JetBrains extensions.

Check it worked:

```bash
claude --version
claude doctor        # deeper health check of your install & config
```

### First run

Claude Code needs a **Pro, Max, Team, or Enterprise** plan (or an API/Bedrock/Vertex key). The free Claude.ai plan doesn't include it.

```bash
cd your-project
claude            # launches the interactive session; follow the browser login
```

That drops you into an interactive prompt inside your repo. Type what you want in plain English and let it work.

### The interactive loop

Once inside a session:

| Action | Key / command |
| --- | --- |
| Send a message | type, then `Enter` |
| **Plan mode** — Claude proposes before touching anything | `Shift`+`Tab` (cycles modes) |
| Run a shell command yourself, output goes into the chat | prefix with `!` |
| Reference a file | `@path/to/file` |
| Interrupt / stop what it's doing | `Esc` |
| Clear context and start fresh | `/clear` |
| See all commands | `/help` |
| Fix your install/config | `/doctor` |

{% hint style="success" %}
The one habit worth building from day one: **use plan mode for anything non-trivial.** Let Claude lay out its approach, correct it, _then_ let it execute. It's far cheaper to fix a plan than to unwind a bad set of edits.
{% endhint %}
