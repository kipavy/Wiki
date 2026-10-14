---
description: The project memory file Claude reads on every session — the highest-leverage setup you can do.
---

# CLAUDE.md

`CLAUDE.md` is a plain Markdown file that Claude Code **automatically loads into context at the start of every session**. It's persistent project memory: instead of re-explaining your build command, your conventions, and your gotchas each time, you write them down once and Claude reads them on every run.

{% hint style="success" %}
If you do only one thing to improve your Claude Code experience, it's this. A good `CLAUDE.md` is worth more than any plugin.
{% endhint %}

### Where it lives

Claude reads `CLAUDE.md` files from several places and merges them, most-specific-wins:

| Location | Scope | Use it for |
| --- | --- | --- |
| `./CLAUDE.md` (repo root) | This project | Build/test commands, architecture, conventions. **Commit this** so your team shares it. |
| `~/.claude/CLAUDE.md` | You, everywhere | Personal preferences that apply to every project (e.g. "always use `uv`, never `pip`"). |
| `./subdir/CLAUDE.md` | A subdirectory | Rules that only apply to one part of a monorepo. Loaded when Claude works in that dir. |
| `./CLAUDE.local.md` | This project, just you | Local-only notes — add it to `.gitignore` so it doesn't get committed. |

### Generating a first draft

Inside a session, run:

```
/init
```

Claude scans the codebase and writes a starter `CLAUDE.md` — languages, structure, how to build and test. Treat it as a **draft**: it's a solid skeleton, but the valuable parts are the things only you know. Edit it.

### What to actually put in it

Aim for **signal, not an essay**. Claude re-reads this every session, so keep it tight and high-value:

* **How to run things** — the exact build, test, lint, and dev-server commands.
* **Conventions that aren't obvious from the code** — "we use snake_case for DB columns, camelCase in the API layer."
* **Architecture in two sentences** — where the important stuff lives, what talks to what.
* **Gotchas** — "the staging env needs `ENV=staging`," "don't touch `legacy/`, it's being deleted."
* **Guardrails** — "never run migrations against prod," "always add a test for new endpoints."

### A good example

```markdown
# Project: acme-api

## Commands
- Install:  uv sync
- Test:     uv run pytest          # run this after any change
- Lint:     uv run ruff check .
- Dev:      uv run fastapi dev app/main.py

## Architecture
FastAPI backend. Routes in `app/routers/`, business logic in `app/services/`,
DB models in `app/models/` (SQLModel). Routers stay thin — logic goes in services.

## Conventions
- Every new endpoint needs a test in `tests/`.
- DB columns: snake_case. API fields: camelCase (handled by response models).
- Never edit files in `app/generated/` — they're regenerated from the OpenAPI spec.

## Don't
- Never run alembic migrations against a non-local database.
```

{% hint style="warning" %}
**Bad `CLAUDE.md` smells:** a wall of generic advice ("write clean code"), duplicating what the code already makes obvious, or letting it rot until it's wrong. Stale instructions are worse than none — Claude will follow them. Prune as the project changes.
{% endhint %}

### Keep it alive

When you catch Claude making the same mistake twice, that's a `CLAUDE.md` entry waiting to be written. You can even ask it mid-session: _"add a note to CLAUDE.md so you remember this next time."_ Over a few weeks the file becomes a genuinely sharp description of how your project wants to be worked on.
