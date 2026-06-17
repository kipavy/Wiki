---
description: Run checks automatically before commits and pushes — catch lint/format errors before they reach CI.
---

# Git Hooks

Git hooks are scripts Git runs automatically at certain points in its lifecycle. The two you'll reach for most are:

* **`pre-commit`** — runs before a commit is created. Exit non-zero and the commit is aborted. Perfect for fast checks: lint, format, type-check the staged files.
* **`pre-push`** — runs before commits are sent to the remote. Exit non-zero and the push is aborted. Good for slower checks you don't want on every commit: the full test suite, a build.

The idea: catch lint/format errors **locally, in seconds**, instead of waiting for a red CI pipeline minutes later.

### Where hooks live

Every repo ships with sample hooks in `.git/hooks/`:

```bash
ls .git/hooks/          # pre-commit.sample, pre-push.sample, ...
```

To activate one, drop an executable file with the matching name (no `.sample` extension) into that folder.

{% hint style="warning" %}
`.git/hooks/` is **not** versioned — it never gets cloned or pushed. A hook you create there only protects your own machine. To share hooks with the team, version them in the repo and point Git at them (see [Sharing hooks](#sharing-hooks-with-the-team) below), or use a manager like `pre-commit` / Husky.
{% endhint %}

### A minimal `pre-commit` example

Block commits that fail lint or formatting. Create `.git/hooks/pre-commit`:

```bash
#!/bin/sh
# Abort the commit if formatting or linting fails.

echo "Running pre-commit checks…"

# Format check (don't auto-fix, just fail loudly)
npm run format:check || {
  echo "❌ Formatting issues — run 'npm run format' and re-stage."
  exit 1
}

# Lint
npm run lint || {
  echo "❌ Lint errors — fix them before committing."
  exit 1
}

echo "✅ pre-commit checks passed."
```

Then make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

{% hint style="info" %}
Need to commit despite a failing hook (e.g. a WIP commit)? Use `git commit --no-verify` (`-n`). Same flag works for `git push --no-verify`. Use sparingly — the point of the hook is to not skip it.
{% endhint %}

### A `pre-push` example (run the tests)

Tests are usually too slow for every commit, so gate them on push instead. Create `.git/hooks/pre-push`:

```bash
#!/bin/sh
# Run the test suite before allowing a push.

echo "Running tests before push…"

npm test || {
  echo "❌ Tests failed — push aborted."
  exit 1
}

echo "✅ Tests passed, pushing."
```

```bash
chmod +x .git/hooks/pre-push
```

### A `commit-msg` example (enforce Conventional Commits)

`commit-msg` receives the path to the file holding the message, so you can validate it and reject anything off-format. Here we require a [Conventional Commits](https://www.conventionalcommits.org/) prefix (`feat:`, `fix:`, …). Create `.git/hooks/commit-msg`:

```bash
#!/bin/sh
# Reject commit messages that don't follow Conventional Commits.

pattern='^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?!?: .+'

if ! grep -qE "$pattern" "$1"; then
  echo "❌ Commit message must look like: 'feat: add login button'"
  echo "   Allowed types: feat, fix, docs, style, refactor, test, chore"
  exit 1
fi
```

```bash
chmod +x .git/hooks/commit-msg
```

A consistent message format is what lets tools auto-generate changelogs and bump versions for you.

### Sharing hooks with the team

Because `.git/hooks/` isn't tracked, commit your hooks somewhere that **is** — e.g. a `.githooks/` folder — then tell Git to use it:

```bash
git config core.hooksPath .githooks
```

Add that one command to your project's setup steps (or a `postinstall` script) so every clone picks the hooks up.

### Hook managers (the practical choice)

For real projects, a manager beats hand-rolled scripts: it versions the config, installs hooks on `npm install`, and runs checks **only on staged files** so commits stay fast.

{% tabs %}
{% tab title="pre-commit (Python, language-agnostic)" %}
Install the [`pre-commit`](https://pre-commit.com/) tool, then add `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.0
    hooks:
      - id: ruff           # lint
        args: [--fix]
      - id: ruff-format    # format
```

```bash
pip install pre-commit
pre-commit install        # wires it into .git/hooks/
```

Despite the name, it manages `pre-push` and other stages too.
{% endtab %}

{% tab title="Husky + lint-staged (JS/TS)" %}
```bash
npm install --save-dev husky lint-staged
npx husky init
```

`package.json`:

```json
{
  "lint-staged": {
    "*.{js,ts,jsx,tsx}": ["eslint --fix", "prettier --write"]
  }
}
```

`.husky/pre-commit`:

```sh
npx lint-staged
```

`lint-staged` runs the tools only against the files you actually staged.
{% endtab %}
{% endtabs %}

### The full list of hooks

`pre-commit` and `pre-push` are the common ones, but Git fires hooks at many points. The client-side ones run on your machine; the server-side ones run on the remote and are handy for team rules nobody can bypass.

**Client-side**

| Hook                 | Fires…                              | Typical use                                  |
| -------------------- | ----------------------------------- | -------------------------------------------- |
| `pre-commit`         | before the commit is created        | lint / format / type-check                   |
| `prepare-commit-msg` | before the message editor opens     | pre-fill the message (templates, ticket #)   |
| `commit-msg`         | after the message is written        | validate the message (Conventional Commits)  |
| `post-commit`        | after the commit is created         | notifications (informational only)           |
| `post-checkout`      | after `checkout` / `switch`         | rebuild, warn if dependencies changed        |
| `post-merge`         | after `merge` / `pull`              | re-run `npm install` if the lockfile changed |
| `pre-rebase`         | before a rebase                     | block rebasing already-published branches    |
| `pre-push`           | before commits are sent             | run tests / build                            |

**Server-side**

| Hook           | Fires…                          | Typical use                                  |
| -------------- | ------------------------------- | -------------------------------------------- |
| `pre-receive`  | before the push is accepted     | reject the whole push if a rule fails        |
| `update`       | like `pre-receive`, per branch  | per-branch rules                             |
| `post-receive` | after the push is accepted      | trigger a deploy, notify Slack / CI          |

{% hint style="info" %}
Hooks are a fast feedback loop, **not** a security boundary — anyone can skip client-side hooks with `--no-verify`. Keep the same lint/test checks in [CI](github-actions.md) (or in a server-side hook) as the real gate; the local hooks just save you the round-trip.
{% endhint %}
</content>
</invoke>
