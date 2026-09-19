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

Confirmed loaded and active on Zotero **9.0.6**, as recorded by Zotero itself:

```json
{ "id": "scihub-ua-fix@thegadflyandmontalleni.github.io",
  "version": "1.0.1", "active": true,
  "appDisabled": false, "userDisabled": false,
  "targetApplications": [{ "id": "zotero@zotero.org",
                           "minVersion": "6.999", "maxVersion": "99.*" }] }
```

---

## Troubleshooting

### "This add-on is not compatible with this version of Zotero"

The version range in the manifest is checked against `zotero@zotero.org`. The two fields
that matter:

- `applications.zotero.strict_max_version` — must cover your Zotero version.
  `99.*` is the safest choice, and is what several widely-used plugins ship.
- `applications.zotero.strict_min_version` — `6.999` is the conventional floor.

A plugin can also be **installed but silently disabled**. Zotero records
`appDisabled: true` when the range does not match, and the add-on manager grays it out
without a prominent error. To see what Zotero actually thinks of a plugin, open
**Tools → Developer → Run JavaScript** and run:

```js
const { AddonManager } = ChromeUtils.importESModule(
  "resource://gre/modules/AddonManager.sys.mjs"
);
const addon = await AddonManager.getAddonByID("scihub-ua-fix@thegadflyandmontalleni.github.io");
return addon
  ? `${addon.version}  active=${addon.isActive}  appDisabled=${addon.appDisabled}`
  : "not installed";
```

On the machine this was developed against, `scipdf` (`maxVersion: "7.*"`) and
`zoteroshortdoi` (`maxVersion: "7.0.*"`) were both **installed but `appDisabled: true`**
on Zotero 9.0.6, while `ccfinfo`, `zoterostyle`, `better-bibtex` and `pdf2zh` (`10.*`)
all loaded fine.

### Building the `.xpi` on Windows

Do **not** use `[System.IO.Compression.ZipFile]::CreateFromDirectory()`. On Windows it
writes ZIP entry names with backslashes:

```
content\icons\icon.svg      <- violates the ZIP spec
```

Readers that follow the spec cannot find the nested files at all, so the archive looks
corrupt. `build.ps1` adds entries one at a time with normalised forward-slash names, and
fails the build if any backslash survives.

Two more things to get right:

- `manifest.json` must be at the archive **root**, not inside a folder.
- `.xpi` is just a zip — no signature is required. `signedState: 0` is normal for
  side-loaded plugins.

### The plugin loads but PDFs still 403

Check the order of the two fixes. The plugin only removes the 403; the resolvers must
*also* be registered with `"automatic": true`, or Zotero's automatic path filters them
out before any request is made. See
[Configuration](#configuration-required--the-plugin-alone-is-not-enough) above.

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
