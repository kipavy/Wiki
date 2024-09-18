# Renaming a pushed commit

#### Renaming the latest commit:

```bash
git commit --amend -m "New commit message"
git push --force origin example-branch
```

#### Renaming any commit:

<pre class="language-bash"><code class="lang-bash">git rebase -i HEAD~n  # Replace n with the number of commits you want to go back
git commit --amend -m "New commit message"
git rebase --continue
git push <a data-footnote-ref href="#user-content-fn-1">-f</a> origin example-branch
</code></pre>

#### Replacing x last commits with 1 new single commit:

```bash
git rebase -i HEAD~x  # Replace x with the number of commits you want to squash into one
pick <commit-hash> Commit message 1
squash <commit-hash> Commit message 2
squash <commit-hash> Commit message 3
git push -f origin example-branch
```

[^1]: \--force
