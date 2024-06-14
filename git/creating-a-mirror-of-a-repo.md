---
description: >-
  This lets you have an exact same copy of a repo on your account, starting from
  a blank repo, ending with the exact same commits, branches...
---

# Creating a mirror of a repo

First create a blank repo on Github or Gitlab or any other.

### Creating Mirror

```bash
git clone --mirror https://gitlab.com/someone/repo.git
cd repo.git
git remote add gitlab https://gitlab.com/you/repo.git
git push --mirror gitlab
```

### Updating mirror

{% hint style="warning" %}
Make sure to have mirror repo not normal repo, if you are not sure just delete your local repo and redo first step
{% endhint %}

```bash
cd repo.git
git fetch origin
git push --mirror gitlab
```
