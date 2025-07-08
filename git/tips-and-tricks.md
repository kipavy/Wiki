# Tips & Tricks

### Change the Date of a Commit (Author and Committer)

Sometimes you want to change the date of a commit, for example to correct a mistake or to mimic a specific timeline. To fully change a commit's date (so both the author and committer dates are updated and GitHub shows the new date), follow these steps:

#### Change the Date of the Last Commit

Alternatively, you can use the [Commit with Date](https://marketplace.visualstudio.com/items?itemName=brandonfowler.commit-with-date) VS Code extension to amend the commit date via a graphical interface.

Replace `YYYY-MM-DD HH:MM:SS` with your desired date and time.

**Bash (Linux/macOS/Git Bash):**

<pre class="language-bash"><code class="lang-bash">DATE="YYYY-MM-DD HH:MM:SS"
GIT_AUTHOR_DATE="$DATE" GIT_COMMITTER_DATE="$DATE" git commit --amend --date="$DATE" <a data-footnote-ref href="#user-content-fn-1">--no-edit</a>
</code></pre>

**PowerShell (Windows):**

<pre class="language-powershell"><code class="lang-powershell">$DATE="YYYY-MM-DD HH:MM:SS"
$env:GIT_AUTHOR_DATE=$DATE
$env:GIT_COMMITTER_DATE=$DATE
git commit <a data-footnote-ref href="#user-content-fn-2">--amend</a> --date="$DATE" <a data-footnote-ref href="#user-content-fn-3">--no-edit</a>
</code></pre>

#### Change the Date of older commits

1.  Start an interactive rebase for the last X commits:

    ```bash
    git rebase -i HEAD~X
    ```
2. In the editor that opens, change `pick` to `edit` for the commit you want to change, save and close the editor.
3.  Change the date of the commit:

    <pre class="language-bash"><code class="lang-bash">DATE="YYYY-MM-DD HH:MM:SS"
    GIT_AUTHOR_DATE="$DATE" GIT_COMMITTER_DATE="$DATE" git commit --amend --date="$DATE" <a data-footnote-ref href="#user-content-fn-3">--no-edit</a>
    </code></pre>
4.  Continue the rebase:

    ```bash
     git rebase --continue
    ```
5. Repeat 3. and 4. for the rest of the commits
6. Push commit to your branch with the following command (replace `branch-name` with your target branch):

   <pre class="language-bash"><code class="lang-bash">git push <a data-footnote-ref href="#user-content-fn-4">--force-with-lease</a> origin branch-name
   </code></pre>

### Push commits in multiple times

The following command will not push X last commit(s):

```bash
git push origin HEAD~X:branch-name 
```

[^1]: `--no-edit` is useful when you want to amend a commit **without changing its commit message**.

[^2]: `--amend` is used to replace a commit

[^3]: `--no-edit` is useful when you want to amend a commit **without changing its commit message**.

[^4]: Use `--force-with-lease` instead of `-f` (--force) to avoid overwriting others' work by accident
