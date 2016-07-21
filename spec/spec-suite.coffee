_ = require 'underscore'
fs = require 'fs-plus'
path = require 'path'
require './spec-helper'

requireSpecs = (specDirectory) ->
  specFilePattern = NylasEnv.getLoadSettings().specFilePattern

  if _.isString(specFilePattern) and specFilePattern.length > 0
    regex = new RegExp(specFilePattern)
  else
    regex = /-spec\.(coffee|js|jsx|cjsx|es6|es)$/

  for specFilePath in fs.listTreeSync(specDirectory)
    require(specFilePath) if regex.test(specFilePath)

    # Set spec directory on spec for setting up the project in spec-helper
    setSpecDirectory(specDirectory)

setSpecField = (name, value) ->
  specs = jasmine.getEnv().currentRunner().specs()
  return if specs.length is 0
  for index in [specs.length-1..0]
    break if specs[index][name]?
    specs[index][name] = value

setSpecType = (specType) ->
  setSpecField('specType', specType)

setSpecDirectory = (specDirectory) ->
  setSpecField('specDirectory', specDirectory)

runAllSpecs = ->
  {resourcePath} = NylasEnv.getLoadSettings()

  requireSpecs(path.join(resourcePath, 'spec'))

  setSpecType('core')

  fixturesPackagesPath = path.join(__dirname, 'fixtures', 'packages')
  # packagePaths = NylasEnv.packages.getAvailablePackageNames().map (packageName) ->
  #   NylasEnv.packages.resolvePackagePath(packageName)

  # EDGEHILL_CORE: Look in internal_packages instead of node_modules
  packagePaths = []
  for packagePath in fs.listSync(path.join(resourcePath, "internal_packages"))
    packagePaths.push(packagePath) if fs.isDirectorySync(packagePath)
  packagePaths = _.uniq packagePaths

  packagePaths = _.groupBy packagePaths, (packagePath) ->
    if packagePath.indexOf("#{fixturesPackagesPath}#{path.sep}") is 0
      'fixtures'
    else if packagePath.indexOf("#{resourcePath}#{path.sep}") is 0
      'bundled'
    else
      'user'

  # Run bundled package specs
  requireSpecs(path.join(packagePath, 'spec')) for packagePath in packagePaths.bundled ? []
  setSpecType('bundled')

  # Run user package specs
  requireSpecs(path.join(packagePath, 'spec')) for packagePath in packagePaths.user ? []
  setSpecType('user')

if specDirectory = NylasEnv.getLoadSettings().specDirectory
  requireSpecs(specDirectory)
  setSpecType('user')
else
  runAllSpecs()
