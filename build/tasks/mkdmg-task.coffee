fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'
Promise = require("bluebird")

module.exports = (grunt) ->
  {spawn, rm} = require('./task-helpers')(grunt)

  appName = -> grunt.config.get('atom.appName')
  dmgName = -> "#{appName().split('.')[0]}.dmg"
  buildDir = -> grunt.config.get('atom.buildDir')
  dmgPath = -> path.join(buildDir(), dmgName())
  appDir = -> path.join(buildDir(), grunt.config.get('atom.appName'))

  getDmgExecutable = ->
    new Promise (resolve, reject) ->
      dmgMakerRepo = "yoursway-create-dmg"
      dmgExecutable = path.join(dmgMakerRepo, "create-dmg")
      if fs.existsSync(dmgExecutable) then resolve(dmgExecutable)
      else
        console.log("---> Downloading yoursway-create-dmg")
        spawn
          cmd: "git"
          args: ["clone", "https://github.com/andreyvit/#{dmgMakerRepo}"]
        , (error, results, exitCode) ->
          if exitCode is 0 then resolve(dmgExecutable) else reject(error)

  removeOldDmg = (dmgExecutable) ->
    if fs.existsSync(dmgPath()) then rm dmgPath()

  executeDmgMaker = (dmgExecutable) ->
    new Promise (resolve, reject) ->
      console.log("---> Bulding Edgehill DMG")
      spawn
        cmd: dmgExecutable
        args: [
          "--volname", "Edgehill Installer",
          "--volicon", path.join("resources", "edgehill.png"),
          "--window-pos", "200", "120",
          "--window-size", "800", "400",
          "--icon-size", "100",
          "--icon", appName(), "200", "190",
          "--hide-extension", appName(),
          "--app-drop-link", "600", "185",
          dmgPath()
          appDir(),
        ]
      , (error, results, exitCode) ->
        if exitCode is 0 then resolve() else reject(error)

  grunt.registerTask 'mkdmg', 'Create Mac DMG', ->
    done = @async()
    removeOldDmg()
    getDmgExecutable()
    .then(executeDmgMaker)
    .then(done)
    .catch (error) ->
      console.error(error)
      done()
