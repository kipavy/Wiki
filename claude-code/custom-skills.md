---
description: Backup copies of personal Claude Code skills (~/.claude/skills/), since no dedicated backup/restore service exists for them yet.
---

# Custom Skills

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

1. **Clarify constraints first** (ask, don't assume): pickup radius/city, storage
   space, budget, categories of interest — or brainstorm some if the user wants
   ideas. Unless the user says otherwise, assume the default objective from the
   Overview (high yield + fastest/easiest resale + least storage/handling hassle)
   and say so explicitly, so they can correct it if they'd rather optimize for raw
   margin alone.

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
   - Leboncoin: `mcp__leboncoin__batch_search_listings` with `departments`/`zipcodes`
     set to the pickup area, `sortBy: "price"`, `sortOrder: "asc"`, and a **modest
     limit (~15-20) per query** — larger batches blow the tool's output cap and get
     dumped to a file.
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
   - Judge deals against **price anchors you supply in the prompt**: the current new/retail
     price (check it with a live WebSearch for the exact model — don't rely on memory,
     tech prices especially move fast and a stale mental price makes a bad deal look good)
     plus a ballpark used-market value per sub-type/condition. Without anchors a subagent's
     "good deal" verdict is a guess, not an analysis. Treat `analyze_market_price` /
     `compare_prices` verdicts as a hint, not ground truth — their own comparable panel can
     be polluted by irrelevant listings (e.g. full PCs/laptops pulled in when hunting a
     component), silently skewing the "fair"/"good deal" label; sanity-check against the
     retail-price anchor before trusting it.
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
   user to confirm availability before traveling.

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
- Trusting `analyze_market_price`'s label at face value → its comparable panel can be dominated by
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
