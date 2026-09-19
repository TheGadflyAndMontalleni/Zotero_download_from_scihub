/* ============================================================
 *  Sci-Hub UA Fix  --  minimal Zotero bootstrap plugin
 *
 *  Problem
 *  -------
 *  Zotero.VersionHeader (chrome/content/zotero/xpcom/zotero.js)
 *  observes "http-on-modify-request" and rewrites every outgoing
 *  User-Agent to include the application suffix:
 *
 *      Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0)
 *      Gecko/20100101 Firefox/140.0 Zotero/9.0.6
 *                                        ^^^^^^^^^^^
 *
 *  Sci-Hub mirrors sit behind Cloudflare, which answers HTTP 403 to
 *  any request whose UA contains "Zotero/". Zotero's own source
 *  acknowledges this and exposes the escape hatch used below:
 *
 *      Zotero.VersionHeader.registerPlainUAHost(host)
 *
 *  ("Turnstile won't pass with Zotero/ in the UA string")
 *
 *  This plugin calls that for the Sci-Hub hosts on every startup, so
 *  built-in custom PDF resolvers keep working across restarts.
 *
 *  Scope
 *  -----
 *  Only the hosts listed below are affected. Nothing else about
 *  Zotero's HTTP behaviour changes.
 * ============================================================ */

var SciHubUAFix = {
	HOSTS: [
		// Sci-Hub mirrors that serve the article landing page
		"sci-hub.ee",
		"sci-hub.ren",
		"sci-hub.se",
		"sci-hub.st",
		"sci-hub.ru",
		"sci-hub.wf",
		"sci-hub.yt",
		"www.tesble.com",
		"www.wellesu.com",
		"www.et-fine.com",
		// host that actually serves the PDF payload
		"sci.bban.top"
	],

	_debug: function (msg) {
		try {
			Zotero.debug("[SciHubUAFix] " + msg);
		}
		catch (e) { /* debug unavailable during early startup */ }
	},

	/**
	 * Register every host. Retries if Zotero.VersionHeader is not
	 * available yet, since plugin startup can race core initialisation.
	 *
	 * @param {Number} [attempt]
	 */
	apply: function (attempt) {
		attempt = attempt || 0;

		try {
			if (Zotero.VersionHeader
				&& typeof Zotero.VersionHeader.registerPlainUAHost === "function") {
				for (let host of this.HOSTS) {
					Zotero.VersionHeader.registerPlainUAHost(host);
				}
				this._debug("registered " + this.HOSTS.length + " plain-UA hosts");
				return;
			}
			this._debug("registerPlainUAHost not available yet (attempt " + attempt + ")");
		}
		catch (e) {
			this._debug("error while registering: " + e);
		}

		if (attempt < 15) {
			setTimeout(() => this.apply(attempt + 1), 1000);
		}
		else {
			this._debug("giving up after " + attempt + " attempts");
		}
	}
};

function startup({ id, version, rootURI }, reason) {
	SciHubUAFix._debug("starting v" + version);

	Promise.resolve()
		.then(() => Zotero.initializationPromise)
		.then(() => SciHubUAFix.apply(0))
		.catch((e) => SciHubUAFix._debug("startup error: " + e));
}

function shutdown(data, reason) {
	// Nothing persistent to undo: registerPlainUAHost() only affects the
	// in-memory set, which dies with the process.
	SciHubUAFix._debug("shutdown (reason " + reason + ")");
}

function install(data, reason) { }
function uninstall(data, reason) { }
