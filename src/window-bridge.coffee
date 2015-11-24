_ = require 'underscore'
{ipcRenderer} = require 'electron'
Utils = require './flux/models/utils'

class WindowBridge
  constructor: ->
    @_tasks = {}
    ipcRenderer.on("remote-run-results", @_onResults)
    ipcRenderer.on("run-in-window", @_onRunInWindow)

  runInWindow: (window, objectName, methodName, args) ->
    taskId = Utils.generateTempId()
    new Promise (resolve, reject) =>
      @_tasks[taskId] = {resolve, reject}
      args = Utils.serializeRegisteredObjects(args)
      params = {window, objectName, methodName, args, taskId}
      ipcRenderer.send("run-in-window", params)

  runInMainWindow: (args...) ->
    @runInWindow("main", args...)

  runInWorkWindow: ->
    @runInWindow("work", args...)

  _onResults: (event, {returnValue, taskId}={}) =>
    returnValue = Utils.deserializeRegisteredObjects(returnValue)
    @_tasks[taskId].resolve(returnValue)
    delete @_tasks[taskId]

  _onRunInWindow: (event, {objectName, methodName, args, taskId}={}) =>
    args = Utils.deserializeRegisteredObjects(args)
    exports = require 'nylas-exports'
    result = exports[objectName][methodName].apply(null, args)
    if _.isFunction(result.then)
      result.then (returnValue) ->
        returnValue = Utils.serializeRegisteredObjects(returnValue)
        ipcRenderer.send('remote-run-results', {returnValue, taskId})
    else
      returnValue = result
      returnValue = Utils.serializeRegisteredObjects(returnValue)
      ipcRenderer.send('remote-run-results', {returnValue, taskId})

module.exports = new WindowBridge
