app = require 'app'
fs = require 'fs'
path = require 'path'
protocol = require 'protocol'

# Handles requests with 'nylas' protocol.
#
# It's created by {N1Application} upon instantiation and is used to create a
# custom resource loader for 'nylas://' URLs.
#
# The following directories are searched in order:
#   * ~/.nylas/assets
#   * ~/.nylas/dev/packages (unless in safe mode)
#   * ~/.nylas/packages
#   * RESOURCE_PATH/node_modules
#
module.exports =
class NylasProtocolHandler
  constructor: (resourcePath, safeMode) ->
    @loadPaths = []
    @dotNylasDirectory = path.join(app.getHomeDir(), '.nylas')

    unless safeMode
      @loadPaths.push(path.join(@dotNylasDirectory, 'dev', 'packages'))

    @loadPaths.push(path.join(@dotNylasDirectory, 'packages'))
    @loadPaths.push(path.join(resourcePath, 'internal_packages'))

    @registerNylasProtocol()

  # Creates the 'Nylas' custom protocol handler.
  registerNylasProtocol: ->
    protocol.registerProtocol 'nylas', (request) =>
      relativePath = path.normalize(request.url.substr(7))

      if relativePath.indexOf('assets/') is 0
        assetsPath = path.join(@dotNylasDirectory, relativePath)
        filePath = assetsPath if fs.statSyncNoException(assetsPath).isFile?()

      unless filePath
        for loadPath in @loadPaths
          filePath = path.join(loadPath, relativePath)
          break if fs.statSyncNoException(filePath).isFile?()

      new protocol.RequestFileJob(filePath)
