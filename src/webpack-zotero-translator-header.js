'use strict';

var ConcatSource = require('webpack-sources').ConcatSource
var ModuleFilenameHelpers = require('webpack/lib/ModuleFilenameHelpers')

function unindent(str) {
  var lines = str.split('\n')
  if (lines[0] == '') lines.shift()

  if (!lines.length) return str

  var indent = lines[0].match(/^ */)
  if (!indent) return str

  indent = RegExp('^' + indent[0])

  lines = lines.map(function(line) { return line.replace(indent, '') })
  return lines.join('\n') + '\n'
}

var TranslatorHeaderPlugin = function (options) {
  if (arguments.length > 1) throw new Error('TranslatorHeaderPlugin only takes one argument (pass an options object)')
	this.options = options || {}
}


TranslatorHeaderPlugin.prototype.apply = function(compiler) {
  var options = this.options;
  var self = this;

  compiler.plugin('compilation', function (compilation) {
    compilation.plugin('optimize-chunk-assets', function (chunks, callback) {
      for (let chunk of chunks) {
        if ('isInitial' in chunk && !chunk.isInitial()) continue;

        for (let file of chunk.files.filter(ModuleFilenameHelpers.matchObject.bind(undefined, options))) {
          var header = require(__dirname + '/resource/' + file + 'on')
          header.lastUpdated = new Date().toISOString().replace('T', ' ').replace(/\..*/, '')
          var preferences = require(__dirname + '/defaults/preferences/defaults.json')

          var prefix = JSON.stringify(header, null, 2) + '\n\n'

          prefix += unindent(`
            var Translator = {
              initialize: function () {},
              release: ${JSON.stringify(options.release)},
              ${header.label.replace(/[^a-z]/ig, '')}: true,
              // header == ZOTERO_TRANSLATOR_INFO -- maybe pick it from there
              header: ${JSON.stringify(header)},
              preferences: ${JSON.stringify(preferences)},
              options: ${JSON.stringify(header.displayOptions || {})},
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
                this.preferences.skipWords = this.preferences.skipWords.toLowerCase().trim().split(/\\s*,\\s*/).filter(function(s) { return s })
                this.preferences.skipFields = this.preferences.skipFields.toLowerCase().trim().split(/\\s*,\\s*/).filter(function(s) { return s })
                this.preferences.rawLaTag = '#LaTeX'
                if (this.preferences.csquotes) {
                  var i, csquotes = { open: '', close: '' }
                  for (i = 0; i < this.preferences.csquotes.length; i++) {
                    csquotes[i % 2 == 0 ? 'open' : 'close'] += this.preferences.csquotes[i]
                  }
                  this.preferences.csquotes = csquotes
                }
                Zotero.debug('preferences loaded: ' + JSON.stringify(this.preferences))
              }
            };

          `)

          if (header.translatorType & 2) { // export
            prefix += unindent(`
              function doExport() {
                Translator.getConfig()
                Translator.initialize()
                Translator.doExport()
              }

            `)
          }
          if (header.translatorType & 1) { // import
            prefix += unindent(`
              function detectImport() {
                return Translator.detectImport()
              }
              function doImport() {
                Translator.getConfig()
                Translator.initialize()
                Translator.doImport()
              }

            `)
          }
          compilation.assets[file] = new ConcatSource(prefix, compilation.assets[file])
        }
      }

      callback();
    })
  })
}

module.exports = TranslatorHeaderPlugin;
