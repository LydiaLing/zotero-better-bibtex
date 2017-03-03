const path = require('path');
const webpack = require('webpack');
const commonsPlugin = new webpack.optimize.CommonsChunkPlugin({ name: 'common', filename: 'common.bundle.js' })
const TranslatorHeaderPlugin = require('./src/webpack/zotero-translator-header')
const PreferencesPlugin = require('./src/webpack/preferences-plugin')

module.exports = function(env) {
  return [
    /*
    {
      plugins: [ commonsPlugin ],
      context: path.resolve(__dirname, './src/chrome/content'),
      entry: {
        betterbibtex: './better-bibtex.js',
        // preferences: './xul/preferences.js'
      },
      output: {
        path: path.resolve(__dirname, './chrome/content'),
        filename: '[name].js',
      },
      module: {
        loaders: [
          { test: /\.js$/, exclude: /node_modules/, loader: "babel-loader" }
        ]
      }
    },
    */

    {
      resolveLoader: {
        alias: {
          'pegjs-loader': path.join(__dirname, './src/webpack/pegjs-loader'),
        },
      },
      plugins: [ new TranslatorHeaderPlugin(env) ],
      context: path.resolve(__dirname, './src/resource'),
      entry: {
        'Better BibLaTeX': './Better BibLaTeX.coffee',
        'Better BibTeX': './Better BibTeX.coffee',
        'Better BibTeX Quick Copy': './Better BibTeX Quick Copy.coffee',
        'Better CSL JSON': './Better CSL JSON.coffee',
        'Better CSL YAML': './Better CSL YAML.coffee',
        'BetterBibTeX JSON': './BetterBibTeX JSON.coffee',
        'Collected Notes': './Collected Notes.coffee',
      },
      output: {
        path: path.resolve(__dirname, './resource'),
        filename: '[name].js',
      },
      module: {
        rules: [
          { test: /\.coffee$/, use: [ 'coffee-loader' ] },
          { test: /\.pegjs$/, use: [ 'pegjs-loader' ] },
        ]
      }
    },

    {
      plugins: [ new PreferencesPlugin(env) ],
      context: path.resolve(__dirname, './src/defaults/preferences'),
      entry: {
        defaults: './defaults.json'
      },
      output: {
        path: path.resolve(__dirname, './defaults/preferences'),
        filename: '[name].js',
      },
    },
  ]
}
