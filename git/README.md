---
icon: git-alt
---

# Git

A practical, copy-paste reference for the Git tasks I actually run into — branching, rewriting history, working with remotes, auth, and CI/CD.

{% hint style="info" %}
New to a topic? Each page leads with _when_ you'd use it, then the commands. Start with **Git Basics**, then dip into whatever you need.
{% endhint %}

### Fundamentals

* [Git Basics](git-basics.md) — the everyday loop (add/commit/push/pull), `.gitignore`, branches, stash, merge vs. rebase, tags.

### Everyday workflow

* [Git Workflows](git-workflows.md) — Gitflow vs. GitHub Flow vs. Trunk-based, with diagrams.
* [Managing Branches](managing-branches.md) — rename, set/change upstream, delete local & remote branches.

### Rewriting history

{% hint style="danger" %}
Everything in this group rewrites history and usually needs a force push. Prefer `--force-with-lease` over `-f`, and avoid it on shared branches.
{% endhint %}

* [Reset and Switch](reset-and-switch.md) — what `HEAD` is, and `reset` vs. `switch --detach`.
* [Rename / Edit / Squash commit(s)](renaming-a-pushed-commit.md) — amend and interactive rebase.
* [Tips & Tricks](tips-and-tricks.md) — change commit dates, push commits in batches, wipe history, delete files/folders from every commit.

### Remotes & collaboration

* [Updating a fork](updating-fork.md) — sync your fork with its upstream.
* [Creating a mirror of a repo](creating-a-mirror-of-a-repo.md) — full copy (all branches/tags) to another host.

### Access & auth

* [SSH Keys & PAT](github-ssh-access-for-private-repo.md) — clone/push to private repos.

### CI/CD

* [CI/CD](github-actions.md) — GitHub Actions & GitLab CI examples (build, test, publish, deploy).
