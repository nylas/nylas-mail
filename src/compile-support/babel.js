'use strict'

var crypto = require('crypto')
var path = require('path')
var defaultOptions = require('../../static/babelrc.json')

var babel = null
var babelVersionDirectory = null

// This adds in the regeneratorRuntime for generators to work properly
// We manually insert it here instead of using the kitchen-sink
// babel-polyfill.
require('babel-regenerator-runtime');

exports.shouldCompile = function (sourceCode, filePath) {
  return (filePath.endsWith('.es6') || filePath.endsWith('.jsx'))
}

exports.getCachePath = function (sourceCode) {
  if (babelVersionDirectory == null) {
    var babelVersion = require('babel-core/package.json').version
    babelVersionDirectory = path.join('js', 'babel', createVersionAndOptionsDigest(babelVersion, defaultOptions))
  }

  return path.join(
    babelVersionDirectory,
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + '.js'
  )
}

exports.compile = function (sourceCode, filePath) {
  if (!babel) {
    babel = require('babel-core');
  }

  var options = {filename: filePath}
  for (var key in defaultOptions) {
    options[key] = defaultOptions[key]
  }
  return babel.transform(sourceCode, options).code
}

function createVersionAndOptionsDigest (version, options) {
  return crypto
    .createHash('sha1')
    .update('babel-core', 'utf8')
    .update('\0', 'utf8')
    .update(version, 'utf8')
    .update('\0', 'utf8')
    .update(JSON.stringify(options), 'utf8')
    .digest('hex')
}
