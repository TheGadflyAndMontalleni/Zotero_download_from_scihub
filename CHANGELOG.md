# Changelog

## 1.0.1

- **Add `icons` (48/96).** Every add-on that loads on the target machine has them;
  this one did not.
- **`strict_max_version`: `10.*` → `99.*`.** `10.*` does work on Zotero 9.0.6 (several
  installed add-ons use it), but `99.*` removes the question entirely and matches what
  other widely-installed plugins ship.
- **Add `update_url` and `update.json`.**
- **Fix a real bug in `build.ps1`.** `[ZipFile]::CreateFromDirectory()` writes ZIP entry
  names with backslashes on Windows (`content\icons\icon.svg`), which violates the ZIP
  spec and makes nested files unreadable to spec-compliant readers. Entries are now
  added one by one with normalised forward-slash names, and the build fails loudly if a
  backslash survives. The previous build only contained root-level files, so it was not
  affected.

## 1.0.0

Initial release.

- Call `Zotero.VersionHeader.registerPlainUAHost()` for the Sci-Hub hosts on every
  startup, stripping the `Zotero/x.y.z` User-Agent suffix that Cloudflare answers with
  HTTP 403.
- Retry loop for the case where the plugin starts before `Zotero.VersionHeader` exists.
- Document the second, independent bug: Zotero's automatic-retrieval path filters out
  custom resolvers unless they set `"automatic": true`
  (`xpcom/attachments.js:1336`).
