# Reset and Switch

### What is HEAD

HEAD is a pointer that represents the current commit. It can be used as a commit id, and you can also refer to commits relative to HEAD. For example, using HEAD\~X (like HEAD\~1, HEAD\~2...) lets you refer to X commits before HEAD.

You can see the \<commit-id> where HEAD is with:

<pre class="language-bash"><code class="lang-bash">git rev-parse HEAD  # for <a data-footnote-ref href="#user-content-fn-1">e.g</a> you could use HEAD~X here
</code></pre>

### Switch to a commit (move HEAD + files)

<pre class="language-bash"><code class="lang-bash"><strong>git switch --detach &#x3C;commit-id>
</strong></code></pre>

### Reset to a commit (move HEAD only)

```bash
git reset <commit-id>
```

For example, here is what you can do if you want to be in the exact same state your collegue was before pushing a commit bbbb on top of a commit aaaa, with his changes in the working tree:

```bash
git switch --detach bbbb && git reset HEAD~1
```

{% hint style="info" %}
`git reset --hard` can be used to also reset files, but be careful, unlike `git switch --detach`, unpushed commits will be lost, and pushed commits will need to be pulled again.
{% endhint %}

### `git reset --hard` vs `git switch --detach`

`git reset --hard`: Modifies your current branch history (by moving the branch pointer) and destroys uncommitted local changes. Can be used to change commits history and pushed with `git push -f`

`git switch --detach`: Does not modify your branch history but puts you in a state where new commits are "detached" from any branch. It's for exploration or temporary work without altering your main branches.

[^1]: example
