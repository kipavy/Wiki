# Managing Branches

Once you're past a single `main` branch, you'll need to rename branches, point them at the right remote, and clean up the ones you're done with. This page covers those everyday branch chores — locally and on the remote.

### List branches

```bash
git branch          # local branches
git branch -r       # remote-tracking branches
git branch -a       # all branches
```

You can list your remotes with `git remote -v`, but most of the time it's `origin`.

### Rename a branch

#### Rename the branch you are currently on

```bash
git branch -m <new-name>
```

#### Rename another branch (without checking it out)

```bash
git branch -m <old-name> <new-name>
```

{% hint style="info" %}
`-m` is short for `--move`. Use `-M` (`--force`) if a branch with the target name already exists and you want to overwrite it.
{% endhint %}

### Update the upstream after renaming

Renaming only touches your **local** branch. The remote still has the old branch name, and your local branch may still track it. To fully sync the rename:

1.  Push the new branch and set it as the upstream:

    <pre class="language-bash"><code class="lang-bash">git push <a data-footnote-ref href="#user-content-fn-1">-u</a> origin &#x3C;new-name>
    </code></pre>
2.  Delete the old branch on the remote:

    ```bash
    git push origin --delete <old-name>
    ```

{% hint style="success" %}
On GitHub you can also rename a branch directly from the repo's **Branches** page, then locally run `git fetch --prune` and `git branch -u origin/<new-name> <new-name>` to re-point your tracking branch.
{% endhint %}

### Set / change the upstream of a branch

The upstream (tracking branch) tells Git _"when I push or pull this local branch, use that remote branch"_.

```bash
git push -u origin <branch>          # push and set upstream in one go
```

To set the upstream without pushing (the branch must already exist on the remote):

```bash
git branch --set-upstream-to=origin/<branch> <branch>
# short form, for the current branch:
git branch -u origin/<branch>
```

Check what each branch tracks:

```bash
git branch -vv
```

Remove the upstream entirely:

```bash
git branch --unset-upstream
```

### Delete a branch

#### Delete a local branch

```bash
git branch -d <branch>     # safe: refuses if not merged
git branch -D <branch>     # force delete (discards unmerged work)
```

#### Delete a remote branch

```bash
git push origin --delete <branch>
```

or the older colon syntax (push "nothing" into the remote branch):

```bash
git push origin :<branch>
```

#### Clean up stale remote-tracking branches

After someone deletes a branch on the remote, your local copy may still list it. Prune it with:

```bash
git fetch --prune
```

[^1]: `-u` is short for `--set-upstream`.
