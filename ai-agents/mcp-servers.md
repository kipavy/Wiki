---
description: A short, opinionated list of MCP servers that actually earn their place — not a mega-directory.
---

# MCP Servers Worth It

**MCP** (Model Context Protocol) lets an agent talk to external systems — docs, browsers, GitHub, databases — through standard tool servers. See [Configuration → MCP servers](../claude-code/configuration.md#mcp-servers-give-claude-new-tools) for how they plug in. There are hundreds out there; this page is deliberately **short** — only the handful I've found genuinely pull their weight.

{% hint style="info" %}
Commands below use Claude Code's `claude mcp add`, but MCP is a standard — the same servers work in **opencode**, **Cline**, and most other agents; only the config syntax differs.
{% endhint %}

Add `--scope user` to any command to make the server available in **every** project instead of just the current one. Check what's connected with `/mcp` inside a session.

---

### Context7

**Live, version-accurate library docs, injected on demand.** Ask the agent to use a library and it pulls that library's _current_ documentation and real code examples into context — instead of leaning on stale training data and inventing APIs that no longer exist. The single biggest fix for "it wrote code against a version that doesn't exist anymore."

```bash
# Remote (recommended). Grab a free key at context7.com/dashboard
claude mcp add --transport http --header "CONTEXT7_API_KEY: YOUR_KEY" context7 https://mcp.context7.com/mcp

# Local alternative
claude mcp add context7 -- npx -y @upstash/context7-mcp --api-key YOUR_KEY
```

{% hint style="info" %}
Context7 recently moved to an API-key model. The free tier still works; the key mainly buys higher rate limits, so it's "strongly recommended" rather than strictly required.
{% endhint %}

**Use it for:** anything touching a fast-moving framework (Next.js, React, a cloud SDK). **Why it's worth it:** near-zero downside, and it kills a whole class of confidently-wrong output.

---

### GitHub

**The agent talks to GitHub directly** — read code and issues, open and review PRs, check Actions, cut releases — without you copy-pasting between the terminal and the browser. This is GitHub's official server (`github/github-mcp-server`).

```bash
# Remote hosted, with a Personal Access Token
claude mcp add --transport http --header "Authorization: Bearer YOUR_GITHUB_PAT" github https://api.githubcopilot.com/mcp/
```

{% hint style="warning" %}
Use the official `github/github-mcp-server` above. The old `@modelcontextprotocol/server-github` npm package is **deprecated and archived** — don't wire that one up.
{% endhint %}

**Use it for:** "triage these open issues," "open a PR from this branch with a proper description," "why did this workflow fail." **Why it's worth it:** collapses the constant context-switch between coding and repo housekeeping.

---

### Playwright

**Lets the agent drive a real browser.** Microsoft's server works from structured accessibility snapshots (not screenshots), so the agent can open a page, click, type, submit forms, and read results deterministically. The reliable way to have Claude _actually check that the thing it built works_.

```bash
claude mcp add playwright -- npx @playwright/mcp@latest
```

**Use it for:** verifying a UI flow end-to-end, reproducing a bug in the browser, scraping a page that needs interaction. **Why it's worth it:** turns "looks right to me" into "I clicked through it and it works."

---

### Chrome DevTools

**Inspect and debug a live running page.** Google's server hooks the agent into a real Chrome instance — read the console, inspect network requests, capture performance traces. Where Playwright _does_ things in the browser, this one _looks inside_ it.

```bash
claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest
```

**Use it for:** "why is this page slow," "what's throwing in the console," "which request is 500-ing." **Why it's worth it:** the agent debugs your web app with the same signals you'd open DevTools for.

---

### Serena

**Semantic, symbol-level code navigation via LSP.** Instead of reading whole files, the agent asks for _symbols_: find this function's definition, every reference to it, its call sites. On a large codebase this is far more precise and token-efficient than grep-and-read.

```bash
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --project "$(pwd)"
```

{% hint style="info" %}
If you install the CLI (`uv tool install serena-agent`), the one-shot `serena setup claude-code` wires it up for you. The current context flag is `--context claude-code` (the older `ide-assistant` still works).
{% endhint %}

**Use it for:** navigating and refactoring a big, unfamiliar codebase. **Why it's worth it:** the agent reasons about your code structurally, and spends its context budget on the right lines instead of whole files.

---

### How they fit together (and where they overlap)

More servers isn't better — some of these overlap, and running both wastes tokens and muddies the agent's choices. Pick per job:

* **Playwright vs. Chrome DevTools** — complementary, with an overlap. **Playwright = act** (automate a flow, click through, submit). **Chrome DevTools = inspect** (console, network, performance). Building/testing a UI flow → Playwright. Debugging why a running page misbehaves → Chrome DevTools. Many people keep both; if you only want one, choose by whether you're mostly _driving_ or _diagnosing_.
* **Serena vs. [graphify](../claude-code/plugins.md#graphify)** — these **overlap, so run one, not both.** Both exist to make a large codebase cheap to navigate, but differently: Serena is **live and precise** (LSP symbols/references, always current with your edits); graphify builds an **upfront knowledge graph** across code _and_ non-code (docs, PDFs, schemas). Rule of thumb: Serena if you mostly need exact symbol-level code navigation; graphify if you want a broader map spanning mixed content. Wiring up both just gives the agent two competing ways to answer the same question.

{% hint style="success" %}
A lean, non-overlapping default: **Context7** (fresh docs) + **GitHub** (repo work) + **Playwright** (verify UIs), and add **Serena _or_ graphify** only when a codebase gets big enough that navigation actually hurts.
{% endhint %}

{% hint style="warning" %}
MCP servers run with real credentials and can touch your repos, browser, and data. Only add ones you trust, prefer official sources, and give each the narrowest token/scope it needs.
{% endhint %}
