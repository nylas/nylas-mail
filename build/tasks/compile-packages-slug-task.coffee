path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
_ = require 'underscore'
KeymapUtils = require '../../src/keymap-utils'

module.exports = (grunt) ->
  {spawn, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'compile-packages-slug', 'Add bundled package metadata information to the main package.json file', ->
    appDir = fs.realpathSync(grunt.config.get('nylasGruntConfig.appDir'))

    modulesDirectory = path.join(appDir, 'node_modules')
    internalNylasPackagesDirectory = path.join(appDir, 'internal_packages')

    modulesPaths = fs.listSync(modulesDirectory)
    modulesPaths = modulesPaths.concat(fs.listSync(internalNylasPackagesDirectory))
    packages = {}

    for moduleDirectory in modulesPaths
      continue if path.basename(moduleDirectory) is '.bin'

      metadataPath = path.join(moduleDirectory, 'package.json')
      metadata = grunt.file.readJSON(metadataPath)
      continue unless metadata?.engines?.nylas?

      moduleCache = metadata._nylasModuleCache ? {}

      extensions = moduleCache.extensions?['.json'] ? []
      i = extensions.indexOf('package.json')
      if i >= 0 then extensions.splice(i, 1)

      for property in ['_from', '_id', 'dist', 'readme', 'readmeFilename']
        delete metadata[property]

      pack = {metadata, keymaps: {}, menus: {}}

      if metadata.main
        mainPath = require.resolve(path.resolve(moduleDirectory, metadata.main))
        pack.main = path.relative(appDir, mainPath)

      for keymapPath in fs.listSync(path.join(moduleDirectory, 'keymaps'), ['.cson', '.json'])
        relativePath = path.relative(appDir, keymapPath)
        keymaps = CSON.readFileSync(keymapPath)
        keymaps = KeymapUtils.cmdCtrlPreprocessor(keymaps)
        pack.keymaps[relativePath] = keymaps

      for menuPath in fs.listSync(path.join(moduleDirectory, 'menus'), ['.cson', '.json'])
        relativePath = path.relative(appDir, menuPath)
        pack.menus[relativePath] = CSON.readFileSync(menuPath)

      packages[metadata.name] = pack

      for extension, paths of moduleCache.extensions
        delete moduleCache.extensions[extension] if paths.length is 0

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))
    metadata._N1Packages = packages

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata))
