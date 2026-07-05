---
description: How the plugin/marketplace system works, plus the plugins actually worth installing.
---

# Plugins Worth It

Plugins extend Claude Code with new skills, slash commands, subagents, hooks, MCP servers, and statusline widgets — bundled so you install a whole workflow in one command. This page covers how the system works, then the plugins I actually keep around.

### How plugins & marketplaces work

A **marketplace** is a source (usually a GitHub repo) that lists plugins. You register a marketplace once, then install plugins from it. The interactive hub for everything is:

```
/plugin
```

…which lets you browse, install, enable/disable, and remove plugins from a menu. If you prefer commands, the flow is two steps — add the marketplace, then install:

```
/plugin marketplace add owner/repo          # register a marketplace
/plugin install <plugin>@<marketplace>      # install from it
```

Anthropic ships two public marketplaces. The official one (`claude-plugins-official`) is registered automatically, so its plugins install with just `/plugin install <name>@claude-plugins-official`. There's also a reviewed community one:

```
/plugin marketplace add anthropics/claude-plugins-community
```

Skills from a plugin are **namespaced** — a `brainstorming` skill from the `superpowers` plugin is invoked as `superpowers:brainstorming`, so plugins never clash.

{% hint style="info" %}
Developing your own? `claude --plugin-dir ./my-plugin` loads a local folder without any marketplace, and `/reload-plugins` hot-reloads changes while you iterate.
{% endhint %}

---

### superpowers

**What it is:** A skills framework that teaches Claude disciplined engineering workflows and triggers them automatically — no special command needed. Built by Jesse Vincent (`obra`). If you've ever wished Claude would _plan properly, test first, and debug methodically instead of guessing_, this is that, systematized.

**Standout skills:**

* **brainstorming** — Socratic requirements-gathering that refines an idea into a spec _before_ any code is written.
* **test-driven-development** — enforced red-green-refactor.
* **systematic-debugging** — root-cause analysis before proposing fixes, instead of throwing patches at symptoms.
* **subagent-driven development**, git-worktree isolation, and a two-stage code review flow.

**Install:**

```
/plugin install superpowers@claude-plugins-official
```

**Why it's worth it:** It's the closest thing to bottling good senior-engineer instincts. The skills fire on their own, so you get the discipline without having to remember to ask for it.

---

### ccstatusline

**What it is:** A highly customizable **status line** for Claude Code — model name, git branch, PR status, token usage, session cost, and a block timer, rendered in Powerline style if you want it. By Matthew Breedlove (`sirmalloc`), MIT licensed.

**Install / configure** — it's an interactive TUI that writes the `statusLine` command into your `settings.json` for you:

```bash
npx -y ccstatusline@latest
```

**Standout features:** live token/cost readout while you work, smart terminal-width handling with flex separators, and GitHub/GitLab PR integration. **Why it's worth it:** the cost and token display alone changes how you work — you _see_ when a session is getting expensive instead of finding out later.

{% hint style="warning" %}
Several similarly named tools exist (`cc-statusline`, `CCometixLine`, other `ccstatusline` forks). The one described here is `sirmalloc/ccstatusline`.
{% endhint %}

---

### graphify

**What it is:** Turns a whole repo — code, SQL schemas, docs, even PDFs and images — into a queryable **knowledge graph**, so Claude queries the graph instead of grepping and reading dozens of files. Extraction runs locally via tree-sitter (no API cost to build the graph). By Graphify Labs.

**Install:**

```bash
uv tool install graphifyy      # note: PyPI package is "graphifyy", command is "graphify"
graphify install               # wires it into Claude Code (and Cursor, Gemini CLI, etc.)
```

Then, inside a session, build the graph for the current project:

```
/graphify .
```

It produces an interactive `graph.html`, a `GRAPH_REPORT.md` of key concepts, and a `graph.json`, and installs a hook so Claude consults the graph before searching files.

**Why it's worth it:** on a large codebase, "where does X actually get handled?" stops being a ten-file scavenger hunt — and it cuts the token cost of Claude re-reading the same files. Most useful the bigger and less familiar the repo is.

---

### getshitdone (GSD)

**What it is:** A spec-driven development system that structures the whole idea-to-code cycle as a chain of slash commands — each command owns one phase (spec → plan → build → review), ideally each in a fresh context window to keep things clean. Originally by TÂCHES.

{% hint style="warning" %}
The original repo (`gsd-build/get-shit-done`) was **archived in mid-2026**; active development moved to **[open-gsd/gsd-core](https://github.com/open-gsd/gsd-core)**. Grab install instructions from there, since the packaging is in flux and several forks with different commands exist.
{% endhint %}

**Why it's worth it:** if you like an opinionated, phase-by-phase pipeline for shipping features (rather than one long free-form session), GSD gives you that scaffolding out of the box. It overlaps conceptually with superpowers' brainstorming→plan→build flow, so try both and keep whichever fits your brain.

---

### caveman

**What it is:** A token-saving prompt-style skill — _"why use many token when few token do trick."_ It makes Claude answer in terse "caveman speak," compressing the prose while keeping **code and commands byte-exact**. By Julius Brussee.

**Install:**

```bash
npx skills add JuliusBrussee/caveman
```

**Standout features:**

* Compression modes: `/caveman lite | full | ultra | wenyan`.
* Companion commands: `/caveman-commit` (terse commit messages), `/caveman-review` (one-line PR comments), `/caveman-compress` (shrink memory files).
* A **statusline badge** showing cumulative tokens saved, e.g. `[CAVEMAN] ⛏ 12.4k`.

**Why it's worth it:** it's half practical (less prose = fewer output tokens = lower cost on chatty sessions), half fun. Reach for it when you want answers, not essays — and turn it off when you actually want Claude to explain its reasoning.

---

### My take

If you install nothing else, install **superpowers** (better engineering by default) and **ccstatusline** (see your cost as you go). Add **graphify** once a codebase gets big enough that navigation hurts. **getshitdone** and **caveman** are worth a try depending on taste — a structured pipeline and a token diet, respectively.

{% hint style="info" %}
Star counts and "saves N× tokens" figures on these projects are marketing — treat them as directional, not gospel. The tools above earn their place on what they _do_, not their numbers.
{% endhint %}
