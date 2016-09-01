fs = require 'fs'
path = require 'path'
os = require 'os'

# This is the main Gruntfile that manages building N1 distributions.
# The reason it's inside of the build/ folder is so everything can be
# compiled against Node's v8 headers instead of Chrome's v8 headers. All
# packages in the root-level node_modules are compiled against Chrome's v8
# headers.
#
# See src/pro/docs/ContinuousIntegration.md for more detailed
# instructions on how we build N1.
#
# Some useful grunt options are:
#   --install-dir
#   --build-dir
#
# To keep the various directories straight, here are what the various
# directories might look like on MacOS
#
# tmpDir: /var/folders/xl/_qdlmc512sb6cpqryy_2tzzw0000gn/T/ (aka /tmp)
#
# buildDir    = /tmp/nylas-build
# shellAppDir = /tmp/nylas-build/Nylas N1.app
# contentsDir = /tmp/nylas-build/Nylas N1.app/Contents
# appDir      = /tmp/nylas-build/Nylas N1.app/Contents/Resources/app
#
# installDir = /Applications/Nylas N1.app
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
  grunt.loadTasks('tasks')

  # This allows all subsequent paths to the relative to the root of the repo
  grunt.file.setBase(path.resolve('..'))

  [major, minor, patch] = packageJson.version.split('.')
  tmpDir = os.tmpdir()
  appName = if process.platform is 'darwin' then 'Nylas N1.app' else 'Nylas'
  appFileName = packageJson.name
  buildDir = grunt.option('build-dir') ? path.join(tmpDir, 'nylas-build')
  buildDir = path.resolve(buildDir)
  installDir = grunt.option('install-dir')

  home = if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME
  electronDownloadDir = path.join(home, '.nylas', 'electron')

  symbolsDir = path.join(buildDir, 'Nylas.breakpad.syms')
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

  grunt.option('appDir', appDir)
  installDir = path.resolve(installDir)

  if process.platform is "linux"
    linuxBinDir = path.join(installDir, "bin")
    linuxShareDir = path.join(installDir, "share", appFileName)
  else
    linuxBinDir = null
    linuxShareDir = null

  cjsxConfig =
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.cjsx'
        'internal_packages/**/*.cjsx'
        '!src/**/node_modules/**/*.cjsx'
        '!internal_packages/**/node_modules/**/*.cjsx'
      ]
      dest: appDir
      ext: '.js'

  coffeeConfig =
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.coffee'
        'internal_packages/**/*.coffee'
        'static/**/*.coffee'
        '!src/**/node_modules/**/*.coffee'
        '!internal_packages/**/node_modules/**/*.coffee'
      ]
      dest: appDir
      ext: '.js'

  babelConfig =
    options: require("../static/babelrc")
    dist:
      files: [{
        expand: true
        src: [
          'src/**/*.es6'
          'src/**/*.es'
          'src/**/*.jsx'
          'internal_packages/**/*.es6'
          'internal_packages/**/*.es'
          'internal_packages/**/*.jsx'
          'static/**/*.es6'
          'static/**/*.es'
        ]
        dest: appDir
        ext: '.js'
      }]

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
        'static/**/*.cson'
      ]
      dest: appDir
      ext: '.json'

  for folder in ['node_modules', 'internal_packages']
    if not fs.existsSync(folder)
      console.log("Ignoring #{folder}, which is missing.")
      continue
    for child in fs.readdirSync(folder) when child isnt '.bin'
      directory = path.join(folder, child)
      metadataPath = path.join(directory, 'package.json')
      continue unless grunt.file.isFile(metadataPath)

      {engines, theme} = grunt.file.readJSON(metadataPath)
      if engines?.nylas?
        lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
        prebuildLessConfig.src.push("#{directory}/**/*.less") unless theme
        csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")

  COFFEE_SRC = [
    'internal_packages/**/*.cjsx'
    'internal_packages/**/*.coffee'
    'dot-nylas/**/*.coffee'
    'src/**/*.coffee'
    'src/**/*.cjsx'
    'spec/**/*.cjsx'
    'spec/**/*.coffee'
    '!src/**/node_modules/**/*.coffee'
    '!internal_packages/**/node_modules/**/*.coffee'
  ]
  ES_SRC = [
    'internal_packages/**/*.jsx'
    'internal_packages/**/*.es6'
    'internal_packages/**/*.es'
    'dot-nylas/**/*.es6'
    'dot-nylas/**/*.es'
    'src/**/*.es6'
    'src/**/*.es'
    'src/**/*.jsx'
    'spec/**/*.es6'
    'spec/**/*.es'
    'spec/**/*.jsx'
    '!src/**/node_modules/**/*.es6'
    '!src/**/node_modules/**/*.es'
    '!src/**/node_modules/**/*.jsx'
    '!internal_packages/**/node_modules/**/*.es6'
    '!internal_packages/**/node_modules/**/*.es'
    '!internal_packages/**/node_modules/**/*.jsx'
  ]

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    nylasGruntConfig: {appDir, appName, appFileName, symbolsDir, buildDir, contentsDir, installDir, shellAppDir, linuxBinDir, linuxShareDir}

    docsOutputDir: 'docs/output'

    coffee: coffeeConfig

    babel: babelConfig

    cjsx: cjsxConfig

    less: lessConfig

    'prebuild-less': prebuildLessConfig

    cson: csonConfig

    nylaslint:
      src: COFFEE_SRC.concat(ES_SRC)

    coffeelint:
      options:
        configFile: 'build/config/coffeelint.json'
      src: COFFEE_SRC
      build: [
        'build/tasks/**/*.coffee'
        'build/Gruntfile.coffee'
      ]
      test: [
        'spec/**/*.cjsx'
        'spec/**/*.coffee'
      ]
      static: [
        'static/**/*.coffee'
        'static/**/*.cjsx'
      ]
      target:
        grunt.option("target")?.split(" ") or []

    eslint:
      options:
        ignore: false
        configFile: 'build/config/eslint.json'
      target: ES_SRC

    eslintFixer:
      src: ES_SRC

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
      token: process.env.NYLAS_GITHUB_OAUTH_TOKEN

    'create-windows-installer':
      installer:
        appDirectory: shellAppDir
        outputDirectory: path.join(buildDir, 'installer')
        authors: 'Nylas Inc.'
        loadingGif: path.resolve(__dirname, 'resources', 'win', 'loading.gif')
        iconUrl: 'http://edgehill.s3.amazonaws.com/static/nylas.ico'
        setupIcon: path.resolve(__dirname, 'resources', 'win', 'nylas.ico')
        certificateFile: process.env.CERTIFICATE_FILE
        certificatePassword: process.env.WINDOWS_CODESIGN_KEY_PASSWORD
        exe: 'nylas.exe'

    shell:
      'kill-n1':
        command: killCommand
        options:
          stdout: false
          stderr: false
          failOnError: false

  grunt.registerTask('compile',
    ['coffee', 'cjsx', 'babel', 'prebuild-less', 'cson'])

  grunt.registerTask('lint',
    ['eslint', 'lesslint', 'nylaslint', 'coffeelint', 'csslint'])

  grunt.registerTask('test', ['shell:kill-n1', 'run-unit-tests'])

  grunt.registerTask('docs', ['build-docs', 'render-docs'])

  # NOTE: add-nylas-build-resources task has already run during
  # script/bootstrap
  #
  buildTasks = [
    'copy-files-for-build',
    'compile',
    'generate-license:save',
    'generate-module-cache',
    'compile-packages-slug']
  buildTasks.push('copy-info-plist') if process.platform is 'darwin'
  buildTasks.push('set-exe-icon') if process.platform is 'win32'
  grunt.registerTask('build', buildTasks)

  ciTasks = ['output-disk-space',
             'download-electron',
             'build']
  ciTasks.push('dump-symbols') if process.platform isnt 'win32'
  ciTasks.push('set-version', 'lint', 'generate-asar')

  if process.platform is "darwin"
    ciTasks.push('test', 'codesign', 'mkdmg')

  else if process.platform is "linux"
    ciTasks.push('mkdeb')
    ciTasks.push('mkrpm')

  else if process.platform is "win32"
    ciTasks.push('create-windows-installer:installer')

  {shouldPublishBuild} = require('./tasks/task-helpers')(grunt)
  if shouldPublishBuild()
    ciTasks.push('publish-nylas-build')

  grunt.registerTask('ci', ciTasks)

  defaultTasks = ['download-electron', 'build', 'set-version', 'generate-asar']
  defaultTasks.push 'mkdmg' if process.platform is 'darwin'
  defaultTasks.push 'install' unless process.platform is 'linux'
  grunt.registerTask('default', defaultTasks)
