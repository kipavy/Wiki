# Renaming a pushed commit

{% hint style="warning" %}
If you want to git push --force on main, you may disable force protection on this branch in repo settings -> branches (e.g: [https://gitlab.com/USER/REPO/-/settings/repository/branch\_rules?branch=main](https://gitlab.com/jeanemar1/test/-/settings/repository/branch\_rules?branch=main))
{% endhint %}

#### Renaming the latest commit:

<pre class="language-bash"><code class="lang-bash"><strong>git commit --amend -m "New commit message"
</strong>git push --force origin example-branch
</code></pre>

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
