---
description: Gotchas when wiring up third-party (non-official) MCP servers on Windows, worked through with a Leboncoin + Vinted example.
---

# Community MCP Servers on Windows

## Prompt: Install Servers From This Page

Paste this into a fresh agent session to have it read this page and offer the worked-example community servers as a menu:

````
Fetch https://kipavy.gitbook.io/it-wiki/ai-coding-agents/mcp-community-servers-windows
and list every "Worked example" server documented on it (name + one-line description of
what it's for). Present them as a numbered menu and ask which ones I want — don't
install anything without my explicit selection. For each one I pick, run its exact
install commands from the page (`npm install -g` / `git clone` + build, then
`claude mcp add`), applying the four gotchas listed at the top of the page as needed
(skip `npx -p`, point `node` at the real entry file rather than the `.cmd` shim, add
`-s user` unless I say I want it project-scoped only, and tell me it won't be usable
until I restart the session). These are unofficial, community-maintained packages that
scrape/automate third-party sites — show me each command before running it, and don't
install anything beyond what I selected. Once done, tell me to restart the session (or
run `/mcp`) to confirm each server connected.
````

The [MCP Servers Worth It](../ai-agents/mcp-servers.md) list covers the polished, official servers. Sometimes what you need is a random community package instead — there's no official Leboncoin or Vinted MCP server, for instance, but people have built and published unofficial ones. These work fine, but expect more friction than `claude mcp add playwright -- npx @playwright/mcp@latest`. Four gotchas showed up wiring up two of them on Windows; all four are generic enough to bite with any community server.

{% hint style="warning" %}
Community MCP servers scrape/automate sites that don't want to be scraped (anti-bot protection, ToS). Use for personal, defensive purposes — don't build harassment or scraping-at-scale tooling on top of them.
{% endhint %}

### 1. `npx -p <package> <bin>` can collide with Claude Code's own `-p`

`claude mcp add name -- npx -y -p @scope/pkg bin-name` looks correct, but Claude Code's own CLI has a global `-p`/`--print` flag, and it can swallow that `-p` before it ever reaches `npx` — the command silently turns into a chat prompt instead of registering the server (you'll see a conversational reply instead of "Added stdio MCP server…").

**Fix:** skip `npx -p` entirely. Install the package globally and point straight at its bin:

```bash
npm install -g @scope/package-name
claude mcp add name -- the-bin-name
```

### 2. On Windows, npm's `.cmd` shim can't be `spawn`'d directly

Even once the package is installed globally, some MCP clients spawn the process directly (no shell), and Windows npm global installs create a `.cmd`/`.ps1` wrapper — not a directly-executable binary. The server shows as connected in `claude mcp list` (that health check goes through a shell) but fails inside an actual session with `spawn ENOENT`.

**Fix:** bypass the shim and call `node` on the real entry point:

```bash
# Find it:
cat "$(npm root -g)/package-name/package.json"   # check "bin" field

# Register with node directly instead of the .cmd shim:
claude mcp add name -- node "C:\Users\you\AppData\Roaming\npm\node_modules\@scope\package-name\dist\entry.js"
```

Same fix applies to a `git clone` + `npm run build` server (TypeScript source): point at `node dist/index.js` rather than any wrapper script.

### 3. Scope follows your **current directory**, not intent

`claude mcp add name -- cmd` defaults to **local scope** — tied to whatever project directory the shell was in *at the moment you ran it*. Add two servers from two different `cwd`s and they end up registered for two different projects; only one shows up in `claude mcp list` from your main project.

**Fix:** add `-s user` to make it available everywhere, and `cd` to a known directory first if scope matters:

```bash
claude mcp add name -s user -- node "C:\path\to\entry.js"
```

### 4. Servers added mid-session don't load until restart

`claude mcp add` edits the config file immediately and `claude mcp list` will show it connected — but the **running session's** tool list was built at startup. New tools aren't callable until you restart Claude Code (or start a fresh session).

{% hint style="info" %}
Want to sanity-check a server without restarting? Talk to it directly over stdio — spawn the same command, send raw JSON-RPC (`initialize` → `tools/list` → `tools/call`). A dozen lines of Node do it; useful for confirming a server actually works before committing to a restart.
{% endhint %}

---

### Worked example: Leboncoin + Vinted MCP

Two unofficial servers, both npm/Node-based, both hit gotchas #1–#3 above:

```bash
# Vinted — global install, point node at the real entry point (gotcha #2)
npm install -g @googlarz/vinted-client
claude mcp add vinted -s user -- node "$(npm root -g)/@googlarz/vinted-client/dist/mcp.js"

# Leboncoin — clone + build, same node-direct approach
git clone https://github.com/NarenkuII/Leboncoin_mcp.git
cd Leboncoin_mcp && npm install && npm run build
claude mcp add leboncoin -s user -- node "$(pwd)/dist/index.js"
```

Both worked with zero extra config — no API keys, no proxy needed for occasional personal use. The Leboncoin server falls back through direct SSR parsing → Jina rendering → browser automation when DataDome blocks a plain request, which covered every search made during testing.

{% hint style="warning" %}
**Marketplace listings go stale fast.** A `search_listings`/`search_items` result is a snapshot — items get sold, reserved, or turn out defective (description says "HS"/"ne fonctionne pas" even though the title looks fine) between the search and when you'd act on it. Before presenting or acting on a result, fetch each candidate's **detail** endpoint (`get_listing_details` / `get_item`) and check for a sold/reserved status field and red-flag words in the full description — not just the title. Cheap insurance against recommending a dead or broken listing.
{% endhint %}
