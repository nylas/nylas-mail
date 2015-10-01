fs = require 'fs'
path = require 'path'
os = require 'os'

# This is the main Gruntfile that manages building N1 distributions.
# The reason it's inisde of the build/ folder is so everything can be
# compiled against Node's v8 headers instead of Atom's v8 headers. All
# packages in the root-level node_modules are compiled against Atom's v8
# headers.
#
# Some useful grunt options are:
#   --instal-dir
#   --build-dir
#
# To keep the various directories straight, here are what the various
# directories might look like on MacOS
#
# tmpDir: /var/folders/xl/_qdlmc512sb6cpqryy_2tzzw0000gn/T/ (aka /tmp)
#
# buildDir    = /tmp/nylas-build
# shellAppDir = /tmp/nylas-build/Nylas.app
# contentsDir = /tmp/nylas-build/Nylas.app/Contents
# appDir      = /tmp/nylas-build/Nylas.app/Contents/Resources/app
#
# installDir = /Applications/Nylas.app
#
# And on Linux:
#
# tmpDir: /tmp/
#
# buildDir    = /tmp/nylas-build
# shellAppDir = /tmp/nylas-build/Nylas
# contentsDir = /tmp/nylas-build/Nylas
# appDir      = /tmp/nylas-build/Nylas/resources/app
#
# installDir = /usr/local OR $INSTALL_PREFIX
# binDir     = /usr/local/bin
# shareDir   = /usr/local/share/nylas

# Add support for obselete APIs of vm module so we can make some third-party
# modules work under node v0.11.x.
require 'vm-compatibility-layer'

_ = require 'underscore'

packageJson = require '../package.json'

# Shim harmony collections in case grunt was invoked without harmony
# collections enabled
_.extend(global, require('harmony-collections')) unless global.WeakMap?

module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-coffeelint-cjsx')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-coffee-react')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-shell')
  grunt.loadNpmTasks('grunt-markdown')
  grunt.loadNpmTasks('grunt-download-electron')
  grunt.loadNpmTasks('grunt-electron-installer')
  grunt.loadNpmTasks('grunt-peg')
  grunt.loadTasks('tasks')

  # This allows all subsequent paths to the relative to the root of the repo
  grunt.file.setBase(path.resolve('..'))

  # Commented out because it was causing normal grunt message to dissapear
  # for some reason.
  # if not grunt.option('verbose')
  #   grunt.log.writeln = (args...) -> grunt.log
  #   grunt.log.write = (args...) -> grunt.log

  [major, minor, patch] = packageJson.version.split('.')
  tmpDir = os.tmpdir()
  appName = if process.platform is 'darwin' then 'Nylas.app' else 'Nylas'
  buildDir = grunt.option('build-dir') ? path.join(tmpDir, 'nylas-build')
  buildDir = path.resolve(buildDir)
  installDir = grunt.option('install-dir')

  home = if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME
  electronDownloadDir = path.join(home, '.nylas', 'electron')

  symbolsDir = path.join(buildDir, 'Atom.breakpad.syms')
  shellAppDir = path.join(buildDir, appName)
  if process.platform is 'win32'
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= path.join(process.env.ProgramFiles, appName)
    killCommand = 'taskkill /F /IM nylas.exe'
  else if process.platform is 'darwin'
    contentsDir = path.join(shellAppDir, 'Contents')
    appDir = path.join(contentsDir, 'Resources', 'app')
    installDir ?= path.join('/Applications', appName)
    killCommand = 'pkill -9 Nylas'
  else
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= process.env.INSTALL_PREFIX ? '/usr/local'
    killCommand = 'pkill -9 nylas'

  installDir = path.resolve(installDir)

  cjsxConfig =
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.cjsx'
        'internal_packages/**/*.cjsx'
      ]
      dest: appDir
      ext: '.js'

  coffeeConfig =
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.coffee'
        'internal_packages/**/*.coffee'
        'exports/**/*.coffee'
        'static/**/*.coffee'
      ]
      dest: appDir
      ext: '.js'

  lessConfig =
    options:
      paths: [
        'static/variables'
        'static'
      ]
    glob_to_multiple:
      expand: true
      src: [
        'static/**/*.less'
      ]
      dest: appDir
      ext: '.css'

  prebuildLessConfig =
    src: [
      'static/**/*.less'
    ]

  csonConfig =
    options:
      rootObject: false
      cachePath: path.join(home, '.nylas', 'compile-cache', 'grunt-cson')

    glob_to_multiple:
      expand: true
      src: [
        'menus/*.cson'
        'keymaps/*.cson'
        'keymaps/templates/*.cson'
        'static/**/*.cson'
      ]
      dest: appDir
      ext: '.json'

  pegConfig =
    glob_to_multiple:
      expand: true
      src: ['src/**/*.pegjs']
      dest: appDir
      ext: '.js'

  for folder in ['node_modules', 'internal_packages']
    for child in fs.readdirSync(folder) when child isnt '.bin'
      directory = path.join(folder, child)
      metadataPath = path.join(directory, 'package.json')
      continue unless grunt.file.isFile(metadataPath)

      {engines, theme} = grunt.file.readJSON(metadataPath)
      if engines?.atom?
        coffeeConfig.glob_to_multiple.src.push("#{directory}/**/*.coffee")
        lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
        prebuildLessConfig.src.push("#{directory}/**/*.less") unless theme
        csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")
        pegConfig.glob_to_multiple.src.push("#{directory}/**/*.pegjs")

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    atom: {appDir, appName, symbolsDir, buildDir, contentsDir, installDir, shellAppDir}

    docsOutputDir: 'docs/output'

    coffee: coffeeConfig

    cjsx: cjsxConfig

    less: lessConfig

    'prebuild-less': prebuildLessConfig

    cson: csonConfig

    peg: pegConfig

    nylaslint:
      src: [
        'internal_packages/**/*.cjsx'
        'internal_packages/**/*.coffee'
        'dot-nylas/**/*.coffee'
        'exports/**/*.coffee'
        'src/**/*.coffee'
        'src/**/*.cjsx'
        'spec/**/*.coffee'
        'spec-nylas/**/*.cjsx'
        'spec-nylas/**/*.coffee'
      ]

    coffeelint:
      options:
        configFile: 'build/config/coffeelint.json'
      src: [
        'internal_packages/**/*.cjsx'
        'internal_packages/**/*.coffee'
        'dot-nylas/**/*.coffee'
        'exports/**/*.coffee'
        'src/**/*.coffee'
        'src/**/*.cjsx'
      ]
      build: [
        'build/tasks/**/*.coffee'
        'build/Gruntfile.coffee'
      ]
      test: [
        'spec/**/*.coffee'
        'spec-nylas/**/*.cjsx'
        'spec-nylas/**/*.coffee'
      ]
      static: [
        'static/**/*.coffee'
        'static/**/*.cjsx'
      ]
      target:
        grunt.option("target")?.split(" ") or []

    csslint:
      options:
        'adjoining-classes': false
        'duplicate-background-images': false
        'box-model': false
        'box-sizing': false
        'bulletproof-font-face': false
        'compatible-vendor-prefixes': false
        'display-property-grouping': false
        'fallback-colors': false
        'font-sizes': false
        'gradients': false
        'ids': false
        'important': false
        'known-properties': false
        'outline-none': false
        'overqualified-elements': false
        'qualified-headings': false
        'unique-headings': false
        'universal-selector': false
        'vendor-prefix': false
        'duplicate-properties': false # doesn't place nice with mixins
      src: [
        'static/**/*.css'
      ]

    lesslint:
      src: [
        'internal_packages/**/*.less'
        'dot-nylas/**/*.less'
        'static/**/*.less'
      ]
      options:
        imports: ['variables/*.less']

    markdown:
      guides:
        files: [
          expand: true
          cwd: 'docs'
          src: '**/*.md'
          dest: 'docs/output/'
          ext: '.html'
        ]
        options:
          template: 'docs/template.jst'
          templateContext:
            title: "Documentation"
            tag: "v#{major}.#{minor}"
          markdownOptions:
            gfm: true
          preCompile: (src, context) ->
            fm = require 'json-front-matter'
            parsed = fm.parse(src)
            _.extend(context, parsed.attributes)
            parsed.body

    'download-electron':
      version: packageJson.electronVersion
      outputDir: 'electron'
      downloadDir: electronDownloadDir
      rebuild: true  # rebuild native modules after electron is updated
      token: process.env.ATOM_ACCESS_TOKEN

    'create-windows-installer':
      appDirectory: shellAppDir
      outputDirectory: path.join(buildDir, 'installer')
      authors: 'Nylas Inc.'
      loadingGif: path.resolve(__dirname, 'resources', 'win', 'loading.gif')
      iconUrl: 'http://edgehill.s3.amazonaws.com/static/nylas.ico'
      setupIcon: path.resolve(__dirname, 'resources', 'win', 'nylas.ico')

    shell:
      'kill-atom':
        command: killCommand
        options:
          stdout: false
          stderr: false
          failOnError: false

  grunt.registerTask('compile', ['coffee', 'cjsx', 'prebuild-less', 'cson', 'peg'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint', 'nylaslint'])
  grunt.registerTask('test', ['shell:kill-atom', 'run-edgehill-specs'])
  grunt.registerTask('docs', ['build-docs', 'render-docs'])

  ciTasks = ['output-disk-space', 'download-electron', 'build']
  ciTasks.push('dump-symbols') if process.platform isnt 'win32'
  ciTasks.push('set-version', 'lint', 'generate-asar')
  ciTasks.push('mkdeb') if process.platform is 'linux'
  ciTasks.push('test') if process.platform is 'darwin'
  ciTasks.push('codesign')
  ciTasks.push('mkdmg') if process.platform is 'darwin'
  ciTasks.push('create-windows-installer') if process.platform is 'win32'
  # ciTasks.push('publish-docs') if process.platform is 'darwin'
  ciTasks.push('publish-nylas-build') if process.platform is 'darwin'
  grunt.registerTask('ci', ciTasks)

  defaultTasks = ['download-electron', 'build', 'set-version', 'generate-asar']
  # We don't run `install` on linux because you need to run `sudo`.
  # See docs/build-instructions/linux.md
  # `sudo script/grunt install`
  defaultTasks.push 'mkdmg' if process.platform is 'darwin'
  defaultTasks.push 'install' unless process.platform is 'linux'
  grunt.registerTask('default', defaultTasks)
