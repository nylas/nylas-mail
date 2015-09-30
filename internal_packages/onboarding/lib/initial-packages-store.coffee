path = require 'path'
fs = require 'fs'
async = require 'async'
NylasStore = require 'nylas-store'

class InitialPackagesStore extends NylasStore
  constructor: ->
    @starterPackages = []
    {resourcePath} = atom.getLoadSettings()
    @starterPackagesPath = path.join(resourcePath, "examples")
    @lastError = null
    @loadStarterPackages()

  loadStarterPackages: =>
    fs.readdir @starterPackagesPath, (err, filenames) =>
      return @encounteredError(err) if err
      packageJSONPaths = filenames.map (name) =>
        path.join(@starterPackagesPath, name, 'package.json')

      async.filter packageJSONPaths, fs.exists, (packageJSONPaths) =>
        return @encounteredError(err) if err

        async.map packageJSONPaths, fs.readFile, (err, packageJSONStrings) =>
          return @encounteredError(err) if err

          @starterPackages = packageJSONStrings.map(@parseStarterPackage)
          # Remove falsy values / packages that were not starter packages
          @starterPackages = @starterPackages.filter(Boolean)

          @trigger()

  parseStarterPackage: (jsonString) =>
    try
      json = JSON.parse(jsonString)

    unless json?.isStarterPackage?
      return false
    unless json.icon? and json.title? and json.description?
      console.log("Starter package `#{json.name}` is missing icon, title or description")
      return false

    json.path = path.join(@starterPackagesPath, json.name)
    json.iconPath = path.join(@starterPackagesPath, json.name, json.icon)
    json

  encounteredError: (err) =>
    @lastError = err
    @trigger()

module.exports = new InitialPackagesStore()
