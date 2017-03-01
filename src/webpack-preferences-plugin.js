'use strict';

var ConcatSource = require('webpack-sources').ConcatSource
var ModuleFilenameHelpers = require('webpack/lib/ModuleFilenameHelpers')

var PreferencesPlugin = function (options) {
  if (arguments.length > 1) throw new Error('PreferencesPlugin only takes one argument (pass an options object)')
	this.options = options || {}
}

PreferencesPlugin.prototype.format = function(k, v) {
  return "pref(" + JSON.stringify(k) + ", " + JSON.stringify(v) + ");\n";
}

PreferencesPlugin.prototype.apply = function(compiler) {
  var options = this.options;
  var self = this;

  compiler.plugin('compilation', function (compilation) {
    compilation.plugin('optimize-chunk-assets', function (chunks, callback) {
      for (let chunk of chunks) {
        if ('isInitial' in chunk && !chunk.isInitial()) continue;

        for (let file of chunk.files.filter(ModuleFilenameHelpers.matchObject.bind(undefined, options))) {
          var preferences = require(__dirname + '/defaults/preferences/defaults.json')

          var js = '';
          for (let preference in preferences) {
            js += self.format('extensions.zotero.translators.better-bibtex.' + preference, preferences[preference]);
          }
          js += '\n';
          for (let preference in preferences) {
            js += self.format('services.sync.prefs.sync.extensions.zotero.translators.better-bibtex.' + preference, true);
          }

          compilation.assets[file] = new ConcatSource(js)
        }
      }

      callback();
    })
  })
}

module.exports = PreferencesPlugin;
