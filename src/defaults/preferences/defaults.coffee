defaults = require('./defaults.json')

for k, v of defaults
  pref("extensions.zotero.translators.better-bibtex.#{k}", v)
  pref("services.sync.prefs.sync.extensions.zotero.translators.better-bibtex.#{k}", true)
