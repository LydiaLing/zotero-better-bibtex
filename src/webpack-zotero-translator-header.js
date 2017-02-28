'use strict';

var ConcatSource = require('webpack-sources').ConcatSource
var ModuleFilenameHelpers = require('webpack/lib/ModuleFilenameHelpers')

var TranslatorHeaderPlugin = function (options) {
  if (arguments.length > 1) throw new Error('TranslatorHeaderPlugin only takes one argument (pass an options object)')
	this.options = options || {}
}

TranslatorHeaderPlugin.prototype.apply = function(compiler) {
  var options = this.options;

  compiler.plugin('compilation', function (compilation) {
    compilation.plugin('optimize-chunk-assets', function (chunks, callback) {
      for (let chunk of chunks) {
        if ('isInitial' in chunk && !chunk.isInitial()) continue;

        for (let file of chunk.files.filter(ModuleFilenameHelpers.matchObject.bind(undefined, options))) {
          var header = require(__dirname + '/resource/' + file + 'on')
          header.lastUpdated = new Date().toISOString().replace('T', ' ').replace(/\..*/, '')
          var preferences = require(__dirname + '/defaults/preferences/defaults.json')
          var prefix = `${JSON.stringify(header, null, 2)}

            var Translator = {
              initialize: function () {},
              release: ${JSON.stringify(options.release)},
              ${header.label.replace(/[^a-z]/ig, '')}: true,
              // Also present in ZOTERO_TRANSLATOR_INFO -- maybe pick it from there
              header: ${JSON.stringify(header, null, 2)},
              preferences: ${JSON.stringify(preferences, null, 2)},
              options: ${JSON.stringify(header.displayOptions || {}, null, 2)},
              getConfig: function() {
                var key
                for (key in this.header.displayOptions) {
                  this.options[key] = Zotero.getOption(key)
                }
                // special handling
                this.options.exportPath = Zotero.getOption('exportPath')
                this.options.exportFilename = Zotero.getOption('exportFilename')

                for (key in this.preferences) {
                  this.preferences[key] = Zotero.getHiddenPref('better-bibtex.' + key)
                }
                // special handling
                this.preferences.skipWords = this.preferences.skipWords.trim().split(/\s*,\s*/)
                this.preferences.skipFields = this.preferences.skipFields.trim().split(/\s*,\s*/)
                if (this.preferences.csquotes) {
                  var i, csquotes = { open: '', close: '' }
                  for (i = 0; i < this.preferences.csquotes.length; i++) {
                    csquotes[i % 2 == 0 ? 'open' : 'close'] += this.preferences.csquotes[i]
                  }
                  this.preferences.csquotes = csquotes
                }
              }
            };
          `

          var postfix = ''

          if (header.translatorType & 2) { // export
            postfix += `
              function doExport() {
                Translator.getConfig()
                Translator.initialize()
                Translator.doExport()
              }
            `
          }
          if (header.translatorType & 1) { // import
            postfix += `
              function detectImport() {
                Translator.detectImport()
              }
              function doImport() {
                Translator.getConfig()
                Translator.initialize()
                Translator.doImport()
              }
            `
          }
          compilation.assets[file] = new ConcatSource(prefix, compilation.assets[file], postfix)
        }
      }

      callback();
    })
  })
}

module.exports = TranslatorHeaderPlugin;
