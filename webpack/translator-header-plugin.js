'use strict';

const ConcatSource = require('webpack-sources').ConcatSource;
const ModuleFilenameHelpers = require('webpack/lib/ModuleFilenameHelpers');
const version = require('./version');
const ejs = require('ejs');

var TranslatorHeaderPlugin = function (options) {
  if (arguments.length > 1) throw new Error('TranslatorHeaderPlugin only takes one argument (pass an options object)')
  this.options = options || {}
}

const Header = `
<%- JSON.stringify(header, null, 2) %>

var BetterBibTeX = {
  initialize: function () {},
  version: <%- JSON.stringify(version) %>,
  <%- header.label.replace(/[^a-z]/ig, '') %>: true,
  // header == ZOTERO_TRANSLATOR_INFO -- maybe pick it from there
  header: <%- JSON.stringify(header) %>,
  preferences: <%- JSON.stringify(preferences) %>,
  options: <%- JSON.stringify(header.displayOptions || {}) %>,

  getConfig: function() {
    this.debugEnabled = Zotero.BetterBibTeX.debugEnabled();
    this.unicode = true;

    var key;
    for (key in this.options) {
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
  }
};

<% if (header.translatorType & 2) { /* export */ %>
  function doExport() {
    BetterBibTeX.getConfig()
    BetterBibTeX.initialize()
    BetterBibTeX.doExport()
  }
<% } %>

<% if (header.translatorType & 1) { /* import */ %>
  function detectImport() {
    return BetterBibTeX.detectImport()
  }
  function doImport() {
    BetterBibTeX.getConfig()
    BetterBibTeX.initialize()
    BetterBibTeX.doImport()
  }
<% } %>
`.trim();

TranslatorHeaderPlugin.prototype.apply = function(compiler) {
  var options = this.options;
  var self = this;

  compiler.plugin('compilation', function (compilation) {
    compilation.plugin('optimize-chunk-assets', function (chunks, callback) {
      for (let chunk of chunks) {
        if ('isInitial' in chunk && !chunk.isInitial()) continue;

        for (let file of chunk.files.filter(ModuleFilenameHelpers.matchObject.bind(undefined, options))) {
          var header = require(__dirname + '/../resource/' + file + 'on')
          header.lastUpdated = new Date().toISOString().replace('T', ' ').replace(/\..*/, '');
          header.inRepository = false;
          var preferences = require(__dirname + '/../defaults/preferences/defaults.json')

          compilation.assets[file] = new ConcatSource(ejs.render(Header, {preferences: preferences, header: header, version: version}), compilation.assets[file])
        }
      }

      callback();
    })
  })
}

module.exports = TranslatorHeaderPlugin;
