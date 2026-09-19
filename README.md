# Sci-Hub UA Fix — a Zotero 9 compatibility plugin

A minimal Zotero plugin that makes **Sci-Hub PDF resolvers work again on Zotero 9**.

If Zotero's "Find Available PDF" or automatic PDF retrieval silently fails against
Sci-Hub mirrors with **HTTP 403**, this is the fix.

---

## The problem

Zotero rewrites the `User-Agent` of **every** outgoing HTTP request. The logic lives in
`chrome/content/zotero/xpcom/zotero.js`, in an observer called `Zotero.VersionHeader`:

```js
Services.obs.addObserver(this, "http-on-modify-request", false);
```

so a normal request ends up looking like this:

```
Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0 Zotero/9.0.6
                                                                                   ^^^^^^^^^^^
```

Sci-Hub mirrors sit behind Cloudflare, and Cloudflare answers **403** to any request whose
UA contains `Zotero/`. The result:

| Target                      | Plain Firefox UA | with `Zotero/9.0.6` |
| --------------------------- | ---------------- | ------------------- |
| `sci-hub.ee`                | 200              | **403**             |
| `sci-hub.ren`               | 200              | **403**             |
| `www.tesble.com`            | 200              | 200                 |
| `www.wellesu.com`           | 200              | 200                 |
| `sci.bban.top` (PDF server) | 200              | 200                 |

Zotero's own source code acknowledges this. From the same file:

```js
/**
 * Register a host that needs the "Zotero/[version]" component stripped
 * from its requests' UA. Currently this is only used for hosts that we
 * handle Cloudflare Turnstile challenges on; Turnstile won't pass with
 * Zotero/ in the UA string ...
 */
registerPlainUAHost: function (host) {
    this._plainUAHosts.add(host);
}
```

Zotero already registers `challenges.cloudflare.com`, `www.sciencedirect.com` and a few
others. **Sci-Hub is simply not on that list.**

## The fix

Call `Zotero.VersionHeader.registerPlainUAHost()` for the Sci-Hub hosts on every startup.

That is all this plugin does. It touches nothing else — only the hosts listed in
`bootstrap.js` are affected, and Zotero's HTTP behaviour is otherwise unchanged.

Note that `registerPlainUAHost()` only mutates an in-memory `Set`, which is why a plugin
is needed at all: a one-off console command would be forgotten on the next restart.

---

## Installation

1. Download `scihub-ua-fix.xpi` from this repository.
2. In Zotero: **Tools → Add-ons** (工具 → 插件)
3. Click the gear icon ⚙ → **Install Add-on From File...**
4. Select `scihub-ua-fix.xpi`
5. **Restart Zotero**

After restarting, check the Zotero debug log for:

```
[SciHubUAFix] registered 11 plain-UA hosts
```

## Configuration (required — the plugin alone is not enough)

The plugin only removes the 403. You still need Sci-Hub resolvers registered, and they
must have `"automatic": true` or Zotero's automatic-retrieval path will filter them out.

In Zotero: **Settings → Advanced → Config Editor**, search for
`extensions.zotero.findPDFs.resolvers`, and paste the contents of
[`resolvers.json`](resolvers.json):

```json
[{"name":"Sci-Hub (ee)","method":"GET","url":"https://sci-hub.ee/{doi}","mode":"html","selector":"#pdf","attribute":"src","automatic":true},
 {"name":"Sci-Hub (ren)","method":"GET","url":"https://sci-hub.ren/{doi}","mode":"html","selector":"#pdf","attribute":"src","automatic":true},
 {"name":"Sci-Hub (tesble)","method":"GET","url":"https://www.tesble.com/{doi}","mode":"html","selector":"#pdf","attribute":"src","automatic":true},
 {"name":"Sci-Hub (wellesu)","method":"GET","url":"https://www.wellesu.com/{doi}","mode":"html","selector":"#pdf","attribute":"src","automatic":true}]
```

### Why `"automatic": true` matters

Zotero's automatic retrieval path passes `automatic = true`:

```js
// xpcom/translation/translate_item.js:369
resolvers.push(...Zotero.Attachments.getPDFResolvers(item, ['custom'], true));

// xpcom/server/server_connector.js:705
Zotero.Attachments.getFileResolvers(item, ['oa', 'custom'], true);
```

and `xpcom/attachments.js:1336` then filters:

```js
if (automatic) {
    customResolvers = customResolvers.filter((r) => r.automatic);
}
```

With `"automatic": false` the resolvers are dropped and Sci-Hub is never tried, even
though the manual right-click → "Find Available PDF" path still works.

---

## Verifying

In Zotero: **Tools → Developer → Run JavaScript**, paste this, tick
"Run as async function", and hit Run:

```js
const item = Zotero.Items.get(ZoteroPane.getSelectedItems()[0].id);
const resolvers = Zotero.Attachments.getFileResolvers(item, ["oa", "custom"], true);
return "automatic resolvers = " + resolvers.length;
```

A number greater than 1 means your custom resolvers are being picked up.

---

## Building from source

```powershell
pwsh ./build.ps1
```

This zips `src/manifest.json` and `src/bootstrap.js` into `scihub-ua-fix.xpi`.
Both files must sit at the **root** of the archive, not inside a folder.

---

## Compatibility

| Zotero | Status                          |
| ------ | ------------------------------- |
| 9.x    | tested (9.0.6 / Firefox 140)    |
| 7.x    | should work                     |

`registerPlainUAHost` has existed since Zotero 7. If a future version renames it, the
plugin logs a message and gives up quietly instead of breaking anything.

---

## Disclaimer

Sci-Hub distributes paywalled academic papers without publisher authorisation. It is
legally contested in most jurisdictions, and using it may violate your institution's
policies or your local copyright law.

This plugin does not download anything itself. It is a User-Agent compatibility shim for
a documented Zotero API. What you point it at is your decision and your responsibility.

Before reaching for Sci-Hub, consider the legitimate options, which cover far more than
most people expect:

- **Unpaywall** — already built into Zotero's "Find Available PDF"
- **Author homepages** — a surprising number of papers are self-archived
- **Preprint servers** — arXiv, IACR ePrint, SSRN, bioRxiv, …
- **Your university library** — Zotero's browser connector supports proxy access
- **Interlibrary loan** — for the remainder

## License

MIT — see [LICENSE](LICENSE).
