---
description: Backup copies of personal Claude Code skills (~/.claude/skills/), since no dedicated backup/restore service exists for them yet.
---

# Custom Skills

## Prompt: Install Skills From This Page

Paste this into a fresh agent session (new machine, new profile, or just want to pick
up newer skills) to have it read this page and offer them to you as a menu:

````
Fetch https://kipavy.gitbook.io/it-wiki/ai-coding-agents/claude-code/custom-skills and
list every skill documented on it (name + one-line description). Present them to me as
a numbered menu and ask which ones I want — don't install anything without my explicit
selection, and don't assume I want all of them. For each skill I pick: create
~/.claude/skills/<name>/SKILL.md (or your runtime's equivalent personal-skills
directory) with the exact SKILL.md content from that skill's code block on the page,
verbatim — don't paraphrase or "improve" it. Then run any Setup steps documented for
that skill (e.g. installing an MCP server), asking for confirmation before installing
anything or changing system state. Once done, tell me which skills are ready and that I
need to restart the session (or start a new one) for them to load.
````

Claude Code "skills" are just markdown files under `~/.claude/skills/<name>/SKILL.md`
(project-scoped skills live in `.claude/skills/` inside a repo instead). Nothing syncs
that folder anywhere by default, and there's no dedicated backup/restore SaaS for them
as of 2026-08 — so this wiki doubles as the backup. `agentskills.io` only defines the
file format, it doesn't host or sync anything.

**To restore a skill** on a new machine or after a wipe: create
`~/.claude/skills/<name>/`, copy the `SKILL.md` content below into it, then restart
Claude Code (or start a fresh session) so it picks up the new skill.

## sourcing-resale-deals

Finds underpriced secondhand items to buy and resell for profit (flipping/arbitrage)
on Leboncoin and/or Vinted — geo-filtered to a local pickup radius, phrasing-diversified
searches to catch casually-worded listings, visually vets the shortlist (photos +
descriptions) before recommending anything, and ranks results by yield weighted by how
fast/easily each item resells (not raw margin alone). Also documents installing the
[Leboncoin + Vinted MCP servers](mcp-community-servers-windows.md#worked-example-leboncoin--vinted-mcp)
if they're missing.

Restore path: `~/.claude/skills/sourcing-resale-deals/SKILL.md`

````markdown
---
name: sourcing-resale-deals
description: Use when the user wants to find underpriced items to buy and resell for profit (flipping, arbitrage, "bonnes affaires a revendre") on Leboncoin and/or Vinted, especially with a local pickup radius or limited storage space. Also use when mcp__leboncoin__* or mcp__vinted__* tools are missing and need installing.
---

# Sourcing Resale Deals (Leboncoin + Vinted)

## Overview

Brainstorm sellable categories, run geo-filtered and phrasing-diversified parallel
searches across Leboncoin and Vinted, delegate oversized results to subagents armed
with price anchors, then pull full details and photos on the shortlist to catch
defects and red flags a title/price can't show, and rank findings by margin **and**
how fast/easily the item resells — weighted by the buyer's storage/logistics
constraints. Unless told otherwise, default optimization target is **high yield +
fastest/easiest resale + least storage/handling hassle**, in that combined order —
never raw margin alone.

## When to Use

- "trouve-moi des bonnes affaires a revendre", flip, arbitrage, "acheter pas cher pour revendre"
- The user gives a pickup radius/city (no-shipping constraint) and/or a storage limit
- `mcp__leboncoin__*` / `mcp__vinted__*` tools don't exist yet in this environment (see Setup)

## Setup: Leboncoin + Vinted MCP

Check first: `ToolSearch("select:mcp__leboncoin__search_listings,mcp__vinted__search_items")`.
If found, load and proceed.

If missing entirely, install (use the Bash tool / Git Bash — the `$()` substitutions
need POSIX sh, not PowerShell):

```bash
# Vinted
npm install -g @googlarz/vinted-client
claude mcp add vinted -s user -- node "$(npm root -g)/@googlarz/vinted-client/dist/mcp.js"

# Leboncoin
git clone https://github.com/NarenkuII/Leboncoin_mcp.git
cd Leboncoin_mcp && npm install && npm run build
claude mcp add leboncoin -s user -- node "$(pwd)/dist/index.js"
```

No API key needed. Windows gotchas: never use `npx -p` (collides with Claude Code's
own `-p`/`--print` flag); npm's `.cmd` shim can't be spawned directly, so point `node`
at the real entry file instead (both commands above already do this); scope follows
the current directory unless you pass `-s user`; a server added mid-session only loads
after restarting Claude Code. Full reference:
https://kipavy.gitbook.io/it-wiki/ai-coding-agents/claude-code/mcp-community-servers-windows#worked-example-leboncoin--vinted-mcp

## Workflow

1. **Clarify constraints first** (ask, don't assume): pickup radius **and the exact
   city/commune name** (the radius alone isn't searchable — you need the city to
   resolve a department/geo filter), storage space, budget, categories of interest —
   or brainstorm some if the user wants ideas. A city name has no natural set of
   discrete choices, so ask it as a plain question in your reply rather than via a
   tool that requires 2+ concrete options (e.g. AskUserQuestion rejects a
   single-option/free-text-only question). **Also ask whether shipped/delivered
   listings are acceptable, not just local pickup** — this changes both the search
   scope and the math: accepting delivery opens up Vinted nationally and Leboncoin
   listings outside the pickup radius, but every shipped purchase carries buyer-side
   platform fees + real shipping cost that must be netted from the margin (see step 5
   for the fee formulas) — a deal that looks great on the listed price can shrink
   substantially once landed cost is computed. Local in-person pickup, by contrast,
   costs next to nothing in fees. If the user hasn't said, default to pickup-only and
   say so explicitly. Unless the user says otherwise, assume the default objective
   from the Overview (high yield + fastest/easiest resale + least storage/handling
   hassle) and say so explicitly, so they can correct it if they'd rather optimize
   for raw margin alone.

2. **Brainstorm categories** when the user wants ideas rather than naming items.
   Favor categories with a documented resale market (you can name a ballpark price),
   condition verifiable in person, and — if storage is tight — high-liquidity brands
   that resell in days over obscure ones with bigger theoretical margin but slow turnover.

3. **Design 3-6 query variants per category** — never rely on one literal term:
   - Include layman synonyms; sellers often skip technical terms (nobody types "DIMM" for a RAM stick).
   - Prefer specific brand/model queries over generic category words — generic terms
     ("RAM DDR4", "vélo électrique") pull in noise (bundled setups, unrelated listings)
     that drowns real deals.

4. **Search geo-filtered and in parallel**:
   - Leboncoin: `mcp__leboncoin__batch_search_listings` with `departments` set to the
     pickup area, `ownerType: "private"` (drops pro/shop resellers up front),
     `sortBy: "price"`, `sortOrder: "asc"`, and a **modest limit (~15-20) per query**
     — larger batches blow the tool's output cap and get dumped to a file.
     **`zipcodes` is confirmed broken as of 2026-08**: a search with a `zipcodes`
     filter silently returns 0 results even in a populated area (verified: the exact
     same query with no geo filter returns tens of thousands), while `departments`
     works normally — don't spend time debugging query phrasing when `zipcodes`
     returns 0, switch to `departments` first. A department is much wider than a
     20km pickup radius, so geo-filter the results yourself afterward by matching
     each listing's `location` field against a commune whitelist tiered by real
     distance (P1 <20km / P2 20-35km / exclude beyond) — give that whitelist to
     whichever subagent processes the results. Re-test `zipcodes` occasionally in
     case it gets fixed upstream.
   - Vinted: `mcp__vinted__search_all_items` per category/query (no geo filter beyond
     country — treat it as a national complement, best for compact/shippable goods,
     not bulky local-only items).
   - Fire every category's searches as parallel tool calls in one turn, not sequentially.

5. **When a result overflows to a file** ("exceeds maximum allowed tokens"), dispatch
   **one subagent per file, in parallel, in the foreground** (the synthesis is needed
   before replying). Each subagent must:
   - Read the file 100% in chunks (offset/limit) — never skip sections.
   - Dedupe across the merged queries.
   - Exclude noise: want-to-buy posts ("recherche"/"achète"), pro/shop listings at
     retail price, bundles where the sought item is just a mentioned component
     (e.g. a full PC listing that mentions the RAM you're hunting).
   - Apply the geo-tiers you give it (e.g. P1 <20km / P2 20-35km / P3 further-but-doable)
     and report each listing's tier.
   - Judge deals against **two price anchors, not one**: (a) the current new/retail price
     (live WebSearch for the exact model — don't rely on memory, tech prices especially
     move fast) **and** (b) the actual used-market resale price, since that's what
     actually comes back on resale, not the new price — a big gap to "new" means nothing
     if the used market already prices the item near what you'd pay for it. Get (b) from
     `analyze_market_price` / `compare_prices`, but treat their median as a hint, not
     ground truth: the comparable panel is polluted two opposite ways — bundled/irrelevant
     listings (e.g. full PCs/laptops pulled in when hunting a component) skew it **high**,
     and accessories sold under the product's name (phone cases, watch straps, headphone
     ear pads, screen protectors, spare charging cases at €1-15) skew it **low**. Confirmed
     in testing: an "AirPods Pro 2" comp panel's `minPrice` was €1 (a spare case), an
     "Apple Watch Series 8" panel's `minPrice` was €9 (a strap). Check whether `avgPrice`
     and `medianPrice` roughly agree — close agreement means the panel is probably clean;
     a sharp divergence means outliers are dragging one of them, so manually skim a sample
     of titles and exclude non-full-item listings before trusting the number. Without both
     anchors a subagent's "good deal" verdict is a guess, not an analysis.
   - **Net out platform fees on any shipped transaction** — the listed price is not the
     landed cost. Confirmed rates (verify live, these change): Vinted charges the
     *buyer* a Buyer Protection fee of **0,70€ + 5% of the item price**, added on top
     of the item price and shipping; Leboncoin charges the *buyer* a Transaction
     sécurisée fee of **0,70€ + 5% when shipped**, or a flat **0,99€ when picked up
     in person** (remise en main propre). Both platforms charge private sellers €0
     commission on a standard sale (Vinted only starts charging the *seller* if the
     account gets reclassified "Vinted Pro" past a volume threshold — worth a
     one-line caveat if the user plans high-volume flipping, not for occasional
     deals). Real shipping cost on top: roughly €3-7 for a small/light Vinted parcel,
     €10-15 for a standard Leboncoin colis. So: **when you (the buyer) acquire a
     shipped item**, landed cost = listed price + (0,70€ + 5%×price) + shipping —
     confirmed in testing, a €100 item landed at ~€111 once both were added, and a
     fixed €0,70 fee bites much harder proportionally on cheap items. **When you
     (the seller) resell**, you keep the full listed price — the buyer absorbs the
     fee on that side, so only the acquisition side needs the correction. In-person
     pickup transactions (either side) carry no meaningful fee (€0-0,99) — this is
     another reason to prefer local Leboncoin listings over shipped ones when the
     margin is thin.
   - Flag category-specific risk factors (undisclosed battery health on e-bikes/power
     tools is the single biggest hidden cost — a suspiciously cheap battery-powered item
     is usually a dead-battery trap, not a bargain; missing box/case on collectibles
     cuts value to 40-60% of complete-in-box price **and** raises selling effort —
     see next point).
   - Estimate **selling effort**, separately from storage: a single item sold in one
     listing to one buyer is low effort; a big loose/incomplete lot (e.g. 50+ games
     with no box, sold individually) is high effort even if it's compact and the raw
     margin looks big — each unit needs its own photo, listing, and negotiation. Note
     whether the lot could instead move as one bundled resale (fast, lower total price)
     or only piecemeal (slow, higher total price, more work).
   - Check listing **freshness**: Leboncoin's `publishedAt` (or equivalent date field)
     can be years old — sorting by price surfaces long-dead listings just as readily as
     live ones, and a suspiciously good price is often explained by "this sold in 2022
     and nobody removed it," not by an actual bargain. Confirmed in testing: a batch
     sorted by price asc surfaced listings from 2021, 2023, and 2024 mixed in with
     same-day posts. Flag anything older than ~4-6 weeks as likely stale in the caveat
     column, and put genuinely recent listings ahead of older ones at a similar price —
     don't let an old listing's lower price make it look like the better deal.
   - Return a ranked table: title, price, location+tier, estimated resale, estimated
     margin, selling effort/speed, link, one-line caveat.

6. **Visually vet the shortlist before finalizing** (top ~5-10 candidates per category,
   not the raw dump — this is a per-listing detail fetch, it doesn't scale to hundreds).
   Search-result listings have empty descriptions and no usable photo; only the detail
   endpoints unlock them:
   - Vinted: `mcp__vinted__get_item` returns the full description **and every photo URL**.
   - Leboncoin: `mcp__leboncoin__get_listing_details_batch` returns the full description
     but only **one low-res thumbnail** (no full gallery) — real limitation, don't claim
     to have inspected photos you don't actually have.
   - Download each photo with Bash (`curl -sL -o <scratchpad-path> <url>`, works for
     both `.jpg` and `.webp`), then view it with Read. Look specifically for: damage/wear
     the text doesn't mention, a model/spec printed on the item that contradicts the
     title, and background clues about how the item was kept (dusty/smoky room, filthy
     or cluttered surroundings, cracked/dirty surfaces) — sellers who don't take care of
     their space often don't take care of the item either.
   - Read the full description text too — condition caveats, missing accessories, or
     defects often get dropped from the title but are spelled out here.
   - Fold what you find into the ranked table's caveat column; downgrade or drop a
     candidate whose photo contradicts its listed condition.

7. **Synthesize and rank across categories** by margin weighted by liquidity, selling
   effort, and the storage constraint — never by raw margin alone. A bulky or
   high-effort item (many units to list individually, or slow-moving) ranks below a
   compact, one-shot, fast-moving item even when its theoretical margin is bigger.
   List anomalies separately (implausibly low = stale/scam/placeholder; implausibly
   high = mis-parsed or wrong category) instead of folding them into the ranked list.

8. **Warn on delivery**: listings can sell between research and follow-up — tell the
   user to confirm availability before traveling. **Neither MCP server can message a
   seller** — no send-message tool exists on either `mcp__leboncoin__*` or
   `mcp__vinted__*` (verified: their full tool lists only cover search/detail/seller-
   profile lookups), and the Leboncoin server runs without an authenticated cookie
   (`check_config` reports `cookie.configured: false`) behind Datadome anti-bot
   protection, so even a hypothetical message tool couldn't post as the user's
   identity without a real login session. If the user wants availability confirmed,
   either have them message the seller directly, or — only with their explicit
   go-ahead, since it sends a message under their identity to a third party — offer
   to drive their already-logged-in Chrome session via `claude-in-chrome` to open the
   listing and send one.

## Output Format

Present findings as a markdown table, one per category (or one combined table if
there's only a handful of results overall). Required columns: **Titre/Objet, Prix,
Localisation (+ tier géo), Marge/rendement estimé, Effort/vitesse de revente, Lien**
— every row needs its direct listing URL, not just the standout picks. Add a short
line above or below the table calling out anomalies (suspiciously low/high prices)
and the recommended priority order given the yield/speed/storage trade-off.

## Common Mistakes

- Searching only the technical/literal term → misses casual listings, undercounts real inventory.
- No geo filter → wastes the query budget on nationwide noise useless for in-person pickup.
- One huge query instead of several targeted ones → drowns in bundled/irrelevant listings.
- Ranking by raw margin only → recommends a bulky item that sits unsold when storage is tight,
  or a big loose lot that takes days of individual listing/negotiation to actually liquidate.
- Treating "big margin lot" and "easy sale" as the same thing → a 50-item loose lot can have a
  great total margin and still be a bad recommendation if the user wants a fast, low-effort flip;
  say explicitly whether a deal is a one-shot resale or a multi-listing grind.
- Trusting a subagent's "good deal" verdict with no price anchor supplied → the verdict is a guess.
- Recommending a listing from title/price alone → the search dump has no real description or photo;
  fetch the detail endpoint and actually look at the photo before putting something in a final report.
- Assuming Leboncoin detail calls give a full photo gallery like Vinted does → they only return one
  low-res thumbnail; say so rather than implying a full visual inspection happened.
- Trusting `analyze_market_price`'s label at face value — its comparable panel can be dominated by
  unrelated bundled listings (confirmed in testing: hunting RAM pulled in full PCs, skewing the
  average to 900€+ and mislabeling overpriced RAM kits as "good deal"/"fair"). Always cross-check
  against a live-searched current retail price before accepting the verdict.
- Estimating margin from memory/stale price knowledge → WebSearch the current new price of the exact
  model before declaring a profit real, especially for fast-depreciating tech.
- Not flagging battery-dependent goods → a "too cheap" e-bike/power-tool kit is usually a dead-battery trap.
- Treating "well-known title/brand" as "rare/valuable" — mass-market blockbusters (e.g. a
  bestselling game or a common consumer model) sell in huge volume and are often worth
  less per unit than a niche item with genuine collector demand; verify actual comps,
  don't assume fame equals value.
- Showing *any* comparison/ranking table without the listing link on every row — including
  an interim status update mid-conversation, not just the final consolidated report. A row
  the user can't click is a row they can't act on, no matter how "preliminary" it felt when
  you wrote it. Include the link every time, not just in the last table you produce.
- Trusting the `zipcodes` filter on the Leboncoin MCP tools — confirmed broken (silently
  returns 0 as of 2026-08). Use `departments` and filter communes yourself instead.
- Asking for a free-text value (a pickup city, a budget number) via a tool built for
  discrete choices, padded with one dummy "Autre" option — most such tools reject a
  question with fewer than 2 real options. Ask free-text values as a plain question.
- Anchoring margin on the new/retail price alone — resale happens on the used market,
  which can price close to what you'd pay for the item (e.g. a Bose QC45 bought and
  resold nets almost nothing once compared against real used comps, despite looking like
  a big discount off the new price). Always pull the actual resale-comp price too.
- Sorting by price and treating the cheapest hits as the best deals without checking the
  publish date — confirmed in testing: a "cheap" Steam Deck and a "cheap" Switch Lite
  were listings from 2021-2023, almost certainly long sold. An old stale listing at a low
  price isn't a bargain, it's noise; check freshness before ranking on price.
- Computing margin from the listed price alone on a shipped purchase, ignoring buyer-side
  platform fees — confirmed in testing: a €100 Vinted item landed at ~€111 once the
  0,70€+5% Buyer Protection fee and real shipping were added, shrinking the margin by
  ~10%. Not asking upfront whether the user accepts delivery at all compounds this: it
  either wastes search budget on shipped listings they won't use, or silently overstates
  every margin that should have had fees netted out.
- Pricing a listing against its product *family* instead of its exact variant — confirmed
  in testing: a "Steam Deck 512GB" listing was anchored against the Steam Deck **OLED**
  512GB retail price, but Valve sells 512GB in both LCD and OLED, at meaningfully
  different retail/resale values; the listing turned out to be the cheaper LCD model,
  which inflated the estimated margin. Confirm the specific variant (screen tech,
  storage tier, generation) from the title/description/photo before anchoring price —
  don't assume the highest-value variant just because a search term matches broadly.
- Assuming a messaging tool exists, or offering to "contact the seller," without checking
  the MCP server's actual tool list first — neither `mcp__leboncoin__*` nor
  `mcp__vinted__*` can send messages (search/detail/seller-lookup only), and Leboncoin's
  server has no authenticated session anyway. Verify capabilities before promising them.

## Quick Reference — Tools

| Tool | Use for |
|---|---|
| `mcp__leboncoin__batch_search_listings` | Several Leboncoin queries in one call, deduped |
| `mcp__leboncoin__analyze_market_price` | Sanity-check one listing/price against comparables |
| `mcp__leboncoin__get_listing_details_batch` | Full description + one thumbnail per shortlisted listing |
| `mcp__vinted__search_all_items` | Paginated Vinted search across a category |
| `mcp__vinted__get_item` | Full description + all photo URLs for one Vinted listing |
| `mcp__vinted__compare_prices` | Cross-country price comparison for one item |
| `WebSearch` | Current new/retail price for a shortlisted model — grounds the margin calc in reality |
````

## analyzing-disk-space-windows

Surveys a Windows drive to find what's actually consuming space (top-level folders,
then one level deeper into whichever come back largest), classifies findings by
cleanup mechanism (regenerable cache vs. recoverable trash vs. real user files vs.
system-protected), and requires explicit per-category confirmation before deleting
anything. Written from a real cleanup session (2026-08-09) that freed ~49 GB on
this machine — the "Common Mistakes" section captures gotchas hit live: reparse-point
double-counting, `Get-ChildItem -Recurse` aborting mid-pipeline on a Win32 exception,
`Test-Path -Force` not existing in Windows PowerShell 5.1, and `Clear-RecycleBin`
exceeding a default command timeout on tens of GB.

Restore path: `~/.claude/skills/analyzing-disk-space-windows/SKILL.md`

````markdown
---
name: analyzing-disk-space-windows
description: Use when the user wants to find what's consuming disk space on a Windows machine and identify safe things to delete or clean up — low free space, "libérer de l'espace disque", "mon disque C est plein", "clean up disk C". Windows/PowerShell-specific; for Linux/macOS use du/ncdu instead.
---

# Analyzing Disk Space (Windows)

## Overview

Two-phase approach: (1) survey top-level and per-user folder sizes with PowerShell to
find where the space actually is, without deleting anything, (2) classify what's found
by cleanup mechanism — regenerable cache, recoverable trash, real user files, or
system-protected — and get explicit per-category confirmation before deleting.

## When to Use

- User wants to free disk space on Windows / low free space warnings
- Explicitly NOT for Linux/macOS — use `du`/`ncdu` there instead, this skill's commands
  are Windows PowerShell-specific

## Core Rule: Never Delete Without Confirmation

State findings first, categorized by risk, and ask which categories to act on — even
if the user's original request already said "find things to delete," that phrasing
is a request to *survey*, not a blanket pre-approval to delete. Confirm per category
(corbeille / caches dev / gros fichiers utilisateur / etc.), not once for everything,
since risk varies wildly across categories — emptying the Recycle Bin is zero-risk,
deleting a stranger's-looking folder in Downloads is not.

## Workflow

1. **Get the overall picture first:**
   ```powershell
   Get-PSDrive C | Select-Object @{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}},@{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}}
   ```

2. **Survey top-level folders**, sizing each recursively. Exclude reparse points
   (junctions like `C:\Users\All Users` → `ProgramData`, or WSL/OneDrive mount points)
   to avoid double-counting and pipeline aborts:
   ```powershell
   Get-ChildItem C:\ -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
       $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue -Attributes !ReparsePoint |
           Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
       [PSCustomObject]@{Name=$_.FullName; SizeGB=[math]::Round($size/1GB,2)}
   } | Sort-Object SizeGB -Descending | Format-Table -AutoSize
   ```
   Repeat one level deeper into whichever folders come back largest (typically
   `C:\Users\<user>`, then `AppData\Local`, then `Downloads`) until you've located the
   actual heavy items, not just a heavy parent folder.

3. **Check well-known space hogs directly** rather than waiting for them to surface —
   some sit behind reparse points or take long to enumerate:
   - `C:\$Recycle.Bin` — often huge, always safe to empty
   - `<user>\AppData\Local\Temp`, `npm-cache`, `pnpm`, `go-build`, `ms-playwright`, `Package Cache`
   - `<user>\Downloads` — sort by size and `LastWriteTime`; old installers/ISOs are common
   - `C:\Windows\WinSxS` — component store, real but not casually cleanable (needs
     `DISM /StartComponentCleanup` as admin, modest gains of ~1-3 GB)
   - `C:\Windows.old`, `C:\Windows\SoftwareDistribution\Download` — leftover Windows Update files
   - Browser cache subfolders (`...\User Data\Default\Cache`, `Service Worker\CacheStorage`)
     — clear via the browser's own settings while it's running, not raw file deletion
   - `hiberfil.sys` / `pagefile.sys` / `swapfile.sys` — system-managed, usually
     inaccessible even with `-Force`; don't try to delete manually

4. **Classify findings by cleanup mechanism**, since that determines both risk and the
   right command:

   | Category | Example | How to clean |
   |---|---|---|
   | Regenerable cache | npm/pnpm/go-build/Playwright, Temp | The tool's own clean command (`npm cache clean --force`, `pnpm store prune`, `go clean -cache`) — safer than raw deletion since the tool knows what's locked/in-use |
   | Recoverable trash | Recycle Bin | `Clear-RecycleBin -DriveLetter C -Force` |
   | Real user files | Downloads, Documents | List with size + date, let the user pick — never assume "old" means "unwanted" |
   | Browser-managed cache | Brave/Chrome/Edge cache folders | Clear via browser settings, not file deletion |
   | System-protected | WinSxS, `Windows\Installer`, pagefile | Leave alone or use the OS-native tool (DISM, Disk Cleanup) — not manual `Remove-Item` |

5. **Present a sorted table** (size, category, suggested action), ask which categories
   to act on, then execute only the confirmed ones. Re-check free space afterward and
   report the actual delta, not the sum of estimates.

## Common Mistakes

- Summing `C:\Users` (or any tree containing junctions) without excluding reparse
  points → wildly wrong totals (e.g. `C:\Users\All Users` is a junction to
  `ProgramData`; counting it double-counts, and some junctions loop back on themselves).
- Running `Get-ChildItem -Recurse` over the whole drive in one shot → slow, and one
  Win32 exception partway through can abort the entire pipeline before `Sort-Object`
  emits anything, silently returning zero results instead of a partial list. Scope to
  one subtree at a time instead.
- `Test-Path -Force` doesn't exist in Windows PowerShell 5.1 (only `Get-Item -Force`
  does) — checking a protected file like `hiberfil.sys` needs
  `Get-Item $path -Force -ErrorAction Stop` wrapped in try/catch, not `Test-Path -Force`.
- Deleting a running browser's cache folder directly instead of using its "clear
  browsing data" setting — can corrupt profile state or fail silently on locked files.
- `Clear-RecycleBin` on tens of GB can exceed a default command timeout — run it in
  the background and expect it to take a while; a timeout is not the same as failure.
- Treating "I found large files" as license to delete them — confirm per category, and
  flag ambiguous personal content (e.g. large unlabeled media files) for the user's own
  judgment instead of acting on it.

## Quick Reference — Commands

| Goal | Command |
|---|---|
| Drive free/used space | `Get-PSDrive C \| Select-Object Used,Free` |
| Folder size, no reparse points | `(Get-ChildItem $path -Recurse -Force -Attributes !ReparsePoint \| Measure-Object Length -Sum).Sum` |
| Empty recycle bin | `Clear-RecycleBin -DriveLetter C -Force` |
| npm cache | `npm cache clean --force` |
| pnpm store | `pnpm store prune` |
| Go build cache | `go clean -cache` |
| Component store cleanup (admin) | `Dism.exe /Online /Cleanup-Image /StartComponentCleanup` |
````
