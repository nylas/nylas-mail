fs = require 'fs'
path = require 'path'
_ = require 'underscore'

module.exports = (grunt) ->
  {cp, isAtomPackage, mkdir, rm} = require('./task-helpers')(grunt)

  escapeRegExp = (string) ->
    if string
      return string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
    else
      return ''

  grunt.registerTask 'build', 'Build the application', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    buildDir = grunt.config.get('atom.buildDir')
    appDir = grunt.config.get('atom.appDir')

    rm shellAppDir
    rm path.join(buildDir, 'installer')
    mkdir path.dirname(buildDir)

    if process.platform is 'darwin'
      cp 'electron/Electron.app', shellAppDir, filter: /default_app/
      cp(path.join(shellAppDir, 'Contents', 'MacOS', 'Electron'),
         path.join(shellAppDir, 'Contents', 'MacOS', 'Nylas'))
      rm path.join(shellAppDir, 'Contents', 'MacOS', 'Electron')
    else
      cp 'electron', shellAppDir, filter: /default_app/
      cp path.join(shellAppDir, 'electron'), path.join(shellAppDir, 'nylas')
      rm path.join(shellAppDir, 'electron')

    mkdir appDir

    if process.platform isnt 'win32'
      cp 'atom.sh', path.resolve(appDir, '..', 'new-app', 'atom.sh')

    cp 'package.json', path.join(appDir, 'package.json')
    cp path.join('resources', 'nylas.png'), path.join(appDir, 'nylas.png')

    packageNames = []
    packageDirectories = []
    nonPackageDirectories = [
      'benchmark'
      'dot-nylas'
      'vendor'
      'resources'
    ]

    {devDependencies} = grunt.file.readJSON('package.json')
    for packageFolder in ['node_modules', 'internal_packages']
      for child in fs.readdirSync(packageFolder)
        directory = path.join(packageFolder, child)
        if isAtomPackage(directory)
          packageDirectories.push(directory)
          packageNames.push(child)
        else
          nonPackageDirectories.push(directory)

    # Put any paths here that shouldn't end up in the built Electron.app
    # so that it doesn't becomes larger than it needs to be.
    ignoredPaths = [
      path.join('git-utils', 'deps')
      path.join('less', 'dist')
      path.join('npm', 'doc')
      path.join('npm', 'html')
      path.join('npm', 'man')
      path.join('npm', 'node_modules', '.bin', 'beep')
      path.join('npm', 'node_modules', '.bin', 'clear')
      path.join('npm', 'node_modules', '.bin', 'starwars')
      path.join('pegjs', 'examples')
      path.join('jasmine-reporters', 'ext')
      path.join('jasmine-node', 'node_modules', 'gaze')
      path.join('jasmine-node', 'spec')
      path.join('node_modules', 'nan')
      path.join('build', 'binding.Makefile')
      path.join('build', 'config.gypi')
      path.join('build', 'gyp-mac-tool')
      path.join('build', 'Makefile')
      path.join('build', 'Release', 'obj.target')
      path.join('build', 'Release', 'obj')
      path.join('build', 'Release', '.deps')
      path.join('vendor', 'apm')
      path.join('resources', 'linux')
      path.join('resources', 'mac')
      path.join('resources', 'win')

      # These are only require in dev mode when the grammar isn't precompiled
      path.join('snippets', 'node_modules', 'loophole')
      path.join('snippets', 'node_modules', 'pegjs')
      path.join('snippets', 'node_modules', '.bin', 'pegjs')

      # These aren't needed since WeakMap is built-in
      path.join('emissary', 'node_modules', 'es6-weak-map')
      path.join('property-accessors', 'node_modules', 'es6-weak-map')

      '.DS_Store'
      '.jshintrc'
      '.npmignore'
      '.pairs'
      '.travis.yml'
      'appveyor.yml'
      '.idea'
      '.editorconfig'
      '.lint'
      '.lintignore'
      '.eslintrc'
      '.jshintignore'
      '.gitattributes'
      '.gitkeep'
    ]

    packageNames.forEach (packageName) -> ignoredPaths.push(path.join(packageName, 'spec'))

    ignoredPaths = ignoredPaths.map (ignoredPath) -> escapeRegExp(ignoredPath)

    # Add .* to avoid matching hunspell_dictionaries.
    ignoredPaths.push "#{escapeRegExp(path.join('spellchecker', 'vendor', 'hunspell') + path.sep)}.*"
    ignoredPaths.push "#{escapeRegExp(path.join('build', 'Release') + path.sep)}.*\\.pdb"

    # Ignore *.cc and *.h files from native modules
    ignoredPaths.push "#{escapeRegExp(path.join('ctags', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('git-utils', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('keytar', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('nslog', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('pathwatcher', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('runas', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('scrollbar-style', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{escapeRegExp(path.join('spellchecker', 'src') + path.sep)}.*\\.(cc|h)*"

    # Ignore build files
    ignoredPaths.push "#{escapeRegExp(path.sep)}binding\\.gyp$"
    ignoredPaths.push "#{escapeRegExp(path.sep)}.+\\.target.mk$"
    ignoredPaths.push "#{escapeRegExp(path.sep)}linker\\.lock$"
    ignoredPaths.push "#{escapeRegExp(path.join('build', 'Release') + path.sep)}.+\\.node\\.dSYM"

    # Hunspell dictionaries are only not needed on OS X.
    if process.platform is 'darwin'
      ignoredPaths.push path.join('spellchecker', 'vendor', 'hunspell_dictionaries')
    ignoredPaths = ignoredPaths.map (ignoredPath) -> "(#{ignoredPath})"

    testFolderPattern = new RegExp("#{escapeRegExp(path.sep)}te?sts?#{escapeRegExp(path.sep)}")
    exampleFolderPattern = new RegExp("#{escapeRegExp(path.sep)}examples?#{escapeRegExp(path.sep)}")
    benchmarkFolderPattern = new RegExp("#{escapeRegExp(path.sep)}benchmarks?#{escapeRegExp(path.sep)}")

    nodeModulesFilter = new RegExp(ignoredPaths.join('|'))
    filterNodeModule = (pathToCopy) ->
      return true if benchmarkFolderPattern.test(pathToCopy)

      pathToCopy = path.resolve(pathToCopy)
      nodeModulesFilter.test(pathToCopy) or testFolderPattern.test(pathToCopy) or exampleFolderPattern.test(pathToCopy)

    packageFilter = new RegExp("(#{ignoredPaths.join('|')})|(.+\\.(cson|coffee|cjsx|jsx)$)")
    filterPackage = (pathToCopy) ->
      return true if benchmarkFolderPattern.test(pathToCopy)

      pathToCopy = path.resolve(pathToCopy)
      packageFilter.test(pathToCopy) or testFolderPattern.test(pathToCopy) or exampleFolderPattern.test(pathToCopy)

    for directory in nonPackageDirectories
      cp directory, path.join(appDir, directory), filter: filterNodeModule

    for directory in packageDirectories
      cp directory, path.join(appDir, directory), filter: filterPackage

    cp 'spec', path.join(appDir, 'spec')
    cp 'spec-nylas', path.join(appDir, 'spec-nylas')
    cp 'src', path.join(appDir, 'src'), filter: /.+\.(cson|coffee|cjsx|jsx)$/
    cp 'static', path.join(appDir, 'static')

    cp path.join('apm', 'node_modules', 'atom-package-manager'), path.resolve(appDir, '..', 'new-app', 'apm'), filter: filterNodeModule
    if process.platform isnt 'win32'
      fs.symlinkSync(path.join('..', '..', 'bin', 'apm'), path.resolve(appDir, '..', 'new-app', 'apm', 'node_modules', '.bin', 'apm'))

    if process.platform is 'darwin'
      grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
        unless /.+\.plist/.test(sourcePath)
          grunt.file.copy(sourcePath, path.resolve(appDir, '..', subDirectory, filename))

    if process.platform is 'win32'
      cp path.join('resources', 'win', 'atom.cmd'), path.join(shellAppDir, 'resources', 'cli', 'atom.cmd')
      cp path.join('resources', 'win', 'atom.sh'), path.join(shellAppDir, 'resources', 'cli', 'atom.sh')
      cp path.join('resources', 'win', 'atom.js'), path.join(shellAppDir, 'resources', 'cli', 'atom.js')
      cp path.join('resources', 'win', 'apm.sh'), path.join(shellAppDir, 'resources', 'cli', 'apm.sh')

    if process.platform is 'linux'
      cp path.join('resources', 'linux', 'icons'), path.join(buildDir, 'icons')

    dependencies = ['compile', 'generate-license:save', 'generate-module-cache', 'compile-packages-slug']
    dependencies.push('copy-info-plist') if process.platform is 'darwin'
    dependencies.push('set-exe-icon') if process.platform is 'win32'
    grunt.task.run(dependencies...)
