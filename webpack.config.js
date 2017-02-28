const path = require('path');
const webpack = require('webpack');
const commonsPlugin = new webpack.optimize.CommonsChunkPlugin({ name: 'common', filename: 'common.bundle.js' })
const TranslatorHeaderPlugin = require('./src/webpack-zotero-translator-header')

module.exports = [
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
    plugins: [ new TranslatorHeaderPlugin() ],
    context: path.resolve(__dirname, './src/resource'),
    entry: {
      'Better BibLaTeX': './biblatex.coffee',
      // 'minimal': './minimal.coffee',
    },
    output: {
      path: path.resolve(__dirname, './resource'),
      filename: '[name].js',
    },
  	module: {
      rules: [
        { test: /\.coffee$/, use: [ 'coffee-loader' ] }
      ]
    }
  },
  {
    context: path.resolve(__dirname, './src/defaults/preferences'),
    entry: {
      defaults: './defaults.coffee'
    },
    output: {
      path: path.resolve(__dirname, './defaults/preferences'),
      filename: '[name].js',
    },
  	module: {
      rules: [
        { test: /\.coffee$/, use: [ 'coffee-loader' ] }
      ]
    }
  }
]
