# Tips & Tricks

### Change the Date of a Commit (Author and Committer)

Sometimes you want to change the date of a commit, for example to correct a mistake or to mimic a specific timeline. To fully change a commit's date (so both the author and committer dates are updated and GitHub shows the new date), follow these steps:

#### Change the Date of the Last Commit

Replace `YYYY-MM-DD HH:MM:SS` with your desired date and time.

**Bash (Linux/macOS/Git Bash):**
```bash
DATE="YYYY-MM-DD HH:MM:SS"
GIT_AUTHOR_DATE="$DATE" GIT_COMMITTER_DATE="$DATE" git commit --amend --date="$DATE" --no-edit
```

**PowerShell (Windows):**
```powershell
$DATE="YYYY-MM-DD HH:MM:SS"
$env:GIT_AUTHOR_DATE=$DATE
$env:GIT_COMMITTER_DATE=$DATE
git commit --amend --date="$DATE" --no-edit
```

#### Change the Date of older commits
1. Start an interactive rebase for the last X commits:
   ```bash
   git rebase -i HEAD~X
   ```
2. In the editor that opens, change `pick` to `edit` for the commit you want to change, save and close the editor.
3. Change the date of the commit:
   ```bash
   DATE="YYYY-MM-DD HH:MM:SS"
   GIT_AUTHOR_DATE="$DATE" GIT_COMMITTER_DATE="$DATE" git commit --amend --date="$DATE" --no-edit
   ```
4. Continue the rebase:
   ```bash
    git rebase --continue
    ```
### Push Commits to a Specific Branch
Use the following command to push commits to a specific branch, replacing `branch-name` with your target branch:

```bash
git push --force-with-lease origin branch-name
```

### Push commits in multiple times

The following command will not push X last commit(s):

```bash
git push origin HEAD~X:branch-name 
```