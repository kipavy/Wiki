---
description: Claude Code isn't the only game in town — the terminal & IDE agents worth knowing, including ones with genuinely free models.
---

# Other Agents

[Claude Code](../claude-code/README.md) is excellent, but it needs a paid Anthropic plan and locks you to Claude. Plenty of other agents are worth knowing — some are open-source and model-agnostic, and a few give you **capable models for free**, which is often enough depending on what you're doing. This page maps the landscape.

### How they differ

Four axes tell you most of what you need:

* **Terminal vs IDE** — a TUI in your shell, a VS Code sidebar, or both.
* **Open-source vs proprietary** — can you read the code and self-host the tool itself?
* **Model-agnostic vs locked** — bring any model (your key, local, free), or tied to one provider.
* **Bring-your-own-key vs bundled subscription** — pay the model provider directly (tool is free), or pay one subscription that bundles the models.

{% hint style="info" %}
"The tool is free" and "the models are free" are different things. Most of these tools are free software; whether _running_ them costs money depends on the model you point them at. The **Free?** column below means free-to-actually-use, not just free to download.
{% endhint %}

### At a glance

| Tool | Form | Open source | Model-agnostic | Free to use? |
| --- | --- | --- | --- | --- |
| **Claude Code** _(baseline)_ | Terminal + IDE | ❌ proprietary | ➖ Claude only | ⚠️ needs a paid Anthropic plan |
| **opencode** | Terminal + IDE | ✅ MIT | ✅ any provider | ✅ free models via OpenCode Zen / free keys |
| **Gemini CLI** | Terminal | ✅ Apache-2.0 | ❌ Gemini | ✅✅ free daily quota with a Google account |
| **Qwen Code** | Terminal | ✅ Apache-2.0 | ✅ any provider | ✅✅ generous free quota via Qwen login |
| **Aider** | Terminal | ✅ Apache-2.0 | ✅ any provider | ⚠️ tool free, you pay the model |
| **Codex CLI** | Terminal | ✅ Apache-2.0 | ❌ OpenAI | ⚠️ needs API billing or ChatGPT plan |
| **Cline** / Roo Code | IDE (VS Code) | ✅ Apache-2.0 | ✅ any provider | ✅ free with local models (Ollama) |
| **Cursor** | IDE (+ CLI) | ❌ proprietary | ➖ bundled | ⚠️ limited free tier, then paid |

---

### opencode

**The one to try first if you want free models.** An open-source, provider-agnostic agent built for the terminal (with a desktop app and IDE extensions too). Model-agnostic to the core — Claude, GPT, Gemini, local models, whatever — so you're never locked in. MIT licensed, very actively developed.

**Install:**

```bash
curl -fsSL https://opencode.ai/install | bash
# or: npm i -g opencode-ai@latest   |   brew install opencode
```

**How the free models work** — two routes:

1. **OpenCode Zen**, their curated model gateway, currently offers several **free models in beta**. Enough for a lot of everyday coding without spending anything.
2. **Bring any free key** — point it at OpenRouter's free models, a local [Ollama](https://ollama.com) model, or an existing subscription (it can even use GitHub Copilot / ChatGPT plans).

**Standout features:** built-in `build` (full-access) and `plan` (read-only) agents, a genuinely nice TUI, and the freedom to switch models per task. **Why it's worth it:** the same "agent in your terminal" experience as Claude Code, but free to start and never tied to one model vendor.

{% hint style="info" %}
opencode came out of the **SST** team (the repo has since moved under Anomaly Co). There are unrelated repos with the same name floating around — the one you want is the project at **[opencode.ai](https://opencode.ai)**.
{% endhint %}

---

### Gemini CLI

Google's open-source terminal agent — and the **strongest free-out-of-the-box story**. Sign in with a **personal Google account** and you get a free daily quota (around **1,000 model requests/day** at the time of writing) with access to Gemini 2.5 Pro and its huge ~1M-token context window.

```bash
npm install -g @google/gemini-cli
# or run without installing: npx @google/gemini-cli
```

**Standout features:** free Gemini 2.5 Pro, built-in Google Search grounding, MCP support. **Watch:** it's tied to Google/Gemini models, and free-tier numbers shift over time — check the current quota if it matters.

---

### Qwen Code

Alibaba's Qwen team's agent — a fork of Gemini CLI tuned for Qwen3-Coder, but happy to talk to any OpenAI-compatible model. Notable for a **very generous free tier**: log in with Qwen OAuth and you get on the order of **1,000–2,000 requests/day** with no per-request token cap.

```bash
npm install -g @qwen-code/qwen-code
# or: brew install qwen-code
```

Near-identical UX to Gemini CLI, so if you know one you know the other. **Why it's worth it:** arguably the most generous free coding-agent quota going, and fully model-agnostic if you'd rather bring your own key later.

---

### Aider

The veteran **terminal pair-programmer**. Open-source, model-agnostic, and unusually good at precise diff edits and whole-repo context via its "repo map." It auto-commits each change to git, so every edit is a reviewable, revertible commit.

```bash
python -m pip install aider-install && aider-install
```

The **tool is free**, but there's no bundled free model — you pay whichever provider you use (or make it free by pairing it with a local Ollama model or a free API key). **Standout features:** repo mapping, automatic git commits, voice-to-code, lint-and-test auto-fix.

---

### OpenAI Codex CLI

OpenAI's open-source, terminal-first agent (rewritten in Rust for speed). It runs shell commands in a sandbox and makes multi-file edits, tied to OpenAI's GPT/o-series models.

```bash
npm install -g @openai/codex
# or: brew install codex
```

The CLI is free and open-source, but it needs either **API billing** or a **ChatGPT Plus/Pro/Business** plan (you can sign in with ChatGPT to use your plan's allowance). Not meaningfully free on its own, but a strong pick if you're already in the OpenAI ecosystem.

---

### Cline (and Roo Code)

If you'd rather stay in your editor, **Cline** is the leading open-source agent as a **VS Code sidebar**. Bring-your-own-key and model-agnostic across 30+ providers — and genuinely free if you run **local models** via [Ollama](https://ollama.com) or LM Studio.

Install from the VS Code Marketplace (search "Cline"). **Standout features:** Plan/Act modes (separate reasoning from execution), per-step human approval for edits and commands, strong MCP support. **Roo Code** is a popular fork with more customization (custom modes, more experimental features) — same model-agnostic, local-friendly spirit.

---

### Cursor

The best-known **AI-first editor** (a VS Code fork), now with a terminal CLI too (`cursor-agent`). It's the odd one out here: **proprietary**, with models **bundled under a subscription** rather than bring-your-own-key.

There's a limited free **Hobby** tier (a small monthly allowance of premium requests); real use is Pro at ~$20/mo and up. **Standout features:** best-in-class tab autocomplete, multi-file Composer, agent mode, and background/cloud agents. **Why it's here:** if you want the most polished single-app experience and don't mind paying, it's hard to beat — just know you're trading openness and model choice for that polish.

---

### A different category: OpenClaw

Worth knowing but **not a coding agent in the same sense** as the tools above. [**OpenClaw**](https://github.com/openclaw/openclaw) is an open-source, self-hosted _gateway_ that connects your everyday chat apps — WhatsApp, Slack, Telegram, Signal, iMessage, Discord and more — to an AI assistant that can browse the web, run shell commands, read/write files and _drive_ coding agents on your behalf. It hatches in a terminal (`openclaw onboard`), but the point is talking to your agent from wherever you already chat, not editing code in your shell.

So it doesn't fit the four axes above — think of it as the layer _in front of_ an agent rather than an alternative to opencode or Aider. If you want a personal assistant reachable from your phone that happens to code, it's the one to look at.

---

### Which should I pick?

* **Want the Claude Code experience but free / model-agnostic?** → **opencode.**
* **Want the most capable model for $0, minimal fuss?** → **Gemini CLI** or **Qwen Code.**
* **Live in VS Code and want local/free models?** → **Cline** (or Roo Code).
* **Precise, git-native edits from the terminal?** → **Aider.**
* **Already pay for ChatGPT / want the slickest paid IDE?** → **Codex CLI** / **Cursor.**

{% hint style="success" %}
There's no single winner — these are cheap to try and easy to run side by side. A common setup: **Claude Code** for the hard stuff, plus a **free agent** (opencode / Gemini CLI / Qwen Code) for routine work so you're not burning your paid quota on boilerplate.
{% endhint %}

{% hint style="warning" %}
Free tiers, quotas, and pricing on all of these move fast — the figures above are a snapshot. Check the official page before relying on a specific number.
{% endhint %}
