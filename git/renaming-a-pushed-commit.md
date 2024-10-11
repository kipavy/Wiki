# Rename/Edit previous commit(s)

{% hint style="warning" %}
If you want to git push --force on main, you may disable force protection on this branch in repo settings -> branches (e.g: [https://gitlab.com/USER/REPO/-/settings/repository/branch\_rules?branch=main](https://gitlab.com/jeanemar1/test/-/settings/repository/branch\_rules?branch=main))
{% endhint %}

### Renaming the latest commit

<pre class="language-bash"><code class="lang-bash"><strong>git commit --amend -m "New commit message"
</strong>git push --force origin example-branch
</code></pre>

### Renaming any commit

For example: renaming HEAD\~2 commit (HEAD is latest commit)

```bash
git rebase -i HEAD~2  # Replace 2 with the number of commits you want to go back
```

It will open text editor, You'll see something like this:

<div align="left">

<figure><img src="../.gitbook/assets/image (1).png" alt=""><figcaption></figcaption></figure>

</div>

find the correct pick \<commit hash> message and replace 'pick' to 'reword'

save and exit

<pre class="language-bash"><code class="lang-bash">git push -f <a data-footnote-ref href="#user-content-fn-1">origin example-branch</a>
</code></pre>

### Replacing x last commits with 1 new single commit

<pre class="language-bash"><code class="lang-bash"><strong>git rebase -i HEAD~x  # Replace x with the number of commits you want to squash into one
</strong>pick &#x3C;commit-hash> Commit message 1
squash &#x3C;commit-hash> Commit message 2
squash &#x3C;commit-hash> Commit message 3
<strong># save and exit
</strong><strong># close 2nd text editor (vi reminder: esc+:q)
</strong><strong># You could now if you want remove/add/edit files and then
</strong><strong># git add . &#x26;&#x26; git commit --amend -m "New single commit message"
</strong>git push -f <a data-footnote-ref href="#user-content-fn-2">origin example-branch</a>
</code></pre>

[^1]: can be omitted if its main

[^2]: Could be omitted if your current branch is already tracking the correct remote branch
