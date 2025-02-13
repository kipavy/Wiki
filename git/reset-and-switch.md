# Reset and Switch

### What is HEAD

HEAD refers to latest commit, you can see the \<commit-id> where HEAD is with:

```bash
git rev-parse HEAD
```

HEAD can be used as a \<commit-id>, and it can also be used to go X commits before HEAD:

<pre class="language-bash"><code class="lang-bash"><strong>git switch --detach HEAD~1
</strong></code></pre>

HEAD\~1 refers to the 1 commit before HEAD, if you want to make sure you can use the previous command to see commit hash:

```bash
git rev-parse HEAD
```

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
