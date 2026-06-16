---
description: Keep your fork in sync with the original (upstream) repository.
---

# Updating a fork

When you fork a repo, your copy doesn't update automatically as the original changes. You keep it in sync by adding the original as a second remote (called `upstream`) and pulling its changes into your fork.

### 1. Add the upstream remote (one time)

`origin` already points to **your** fork. Add `upstream` pointing to the **original** repo:

```bash
git remote add upstream https://github.com/ORIGINAL_OWNER/REPO.git
git remote -v   # verify: origin = your fork, upstream = original
```

### 2. Fetch and merge upstream changes

```bash
git fetch upstream
git switch main                 # or master, depending on the repo
git merge upstream/main
git push origin main            # update your fork on GitHub
```

{% hint style="info" %}
Prefer a linear history? Use `git rebase upstream/main` instead of `merge`. You'll then need `git push --force-with-lease origin main`, so only do this on branches nobody else is using.
{% endhint %}

### Shortcut: one-line sync

If your local `main` has no commits of its own, you can fast-forward and push in one go:

```bash
git fetch upstream && git push origin upstream/main:main
```

### Even quicker: the GitHub UI

On GitHub, your fork's page has a **Sync fork** button that pulls in upstream commits without touching the command line. After clicking it, run `git pull` locally to update your clone.

---

Original gist: [https://gist.github.com/kipavy/c5f1ced0532ce21ae0cfd66edb32c739](https://gist.github.com/kipavy/c5f1ced0532ce21ae0cfd66edb32c739)
