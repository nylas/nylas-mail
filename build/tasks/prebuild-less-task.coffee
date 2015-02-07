path = require 'path'
fs = require 'fs'

LessCache = require 'less-cache'

module.exports = (grunt) ->
  grunt.registerMultiTask 'prebuild-less', 'Prebuild cached of compiled LESS files', ->
    prebuiltConfigurations = [
      ['inbox-light-ui']
    ]

    directory = path.join(grunt.config.get('atom.appDir'), 'less-compile-cache')

    for configuration in prebuiltConfigurations
      importPaths = grunt.config.get('less.options.paths')
      themeMains = []
      for theme in configuration
        # TODO Use AtomPackage class once it runs outside of an Atom context
        themePath = path.resolve('node_modules', theme)
        if fs.existsSync(themePath) is false
          themePath = path.resolve('internal_packages', theme)
          
        if fs.existsSync(path.join(themePath, 'stylesheets'))
          stylesheetsDir = path.join(themePath, 'stylesheets')
        else
          stylesheetsDir = path.join(themePath, 'styles')
        {main} = grunt.file.readJSON(path.join(themePath, 'package.json'))
        main ?= 'index.less'
        mainPath = path.join(themePath, main)
        themeMains.push(mainPath) if grunt.file.isFile(mainPath)
        importPaths.unshift(stylesheetsDir) if grunt.file.isDir(stylesheetsDir)

      grunt.verbose.writeln("Building LESS cache for #{configuration.join(', ').yellow}")
      lessCache = new LessCache
        cacheDir: directory
        resourcePath: path.resolve('.')
        importPaths: importPaths

      cssForFile = (file) ->
        baseVarImports = """
        @import "variables/ui-variables";
        """
        less = fs.readFileSync(file, 'utf8')
        lessCache.cssForFile(file, [baseVarImports, less].join('\n'))

      for file in @filesSrc
        grunt.verbose.writeln("File #{file.cyan} created in cache.")
        cssForFile(file)

      for file in themeMains
        grunt.verbose.writeln("File #{file.cyan} created in cache.")
        cssForFile(file)
