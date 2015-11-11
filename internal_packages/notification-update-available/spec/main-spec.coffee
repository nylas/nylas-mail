_ = require 'underscore'
proxyquire = require 'proxyquire'
Reflux = require 'reflux'
{Actions} = require 'nylas-exports'

stubUpdaterState = null
stubUpdaterReleaseVersion = null
ipcSendArgs = null

PackageMain = proxyquire "../lib/main",
  "ipc":
    send: ->
      ipcSendArgs = arguments
  "remote":
    getGlobal: (global) ->
      autoUpdateManager:
        releaseVersion: stubUpdaterReleaseVersion
        getState: -> stubUpdaterState

describe "NotificationUpdateAvailable", ->
  beforeEach ->
    stubUpdaterState = 'idle'
    stubUpdaterReleaseVersion = undefined
    ipcSendArgs = null
    @package = PackageMain

  afterEach ->
    @package.deactivate()

  describe "activate", ->
    it "should display a notification immediately if one is available", ->
      spyOn(@package, 'displayNotification')
      stubUpdaterState = 'update-available'
      @package.activate()
      expect(@package.displayNotification).toHaveBeenCalled()
    
    it "should not display a notification if no update is avialable", ->
      spyOn(@package, 'displayNotification')
      stubUpdaterState = 'no-update-available'
      @package.activate()
      expect(@package.displayNotification).not.toHaveBeenCalled()

    it "should listen for `window:update-available`", ->
      spyOn(NylasEnv, 'onUpdateAvailable').andCallThrough()
      @package.activate()
      expect(NylasEnv.onUpdateAvailable).toHaveBeenCalled()

  describe "displayNotification", ->
    beforeEach ->
      @package.activate()

    it "should fire a postNotification Action", ->
      spyOn(Actions, 'postNotification')
      @package.displayNotification()
      expect(Actions.postNotification).toHaveBeenCalled()

    it "should include the version if one is provided", ->
      spyOn(Actions, 'postNotification')

      version = '0.515.0-123123'
      @package.displayNotification(version)
      expect(Actions.postNotification).toHaveBeenCalled()

      notifOptions = Actions.postNotification.mostRecentCall.args[0]
      expect(notifOptions.message.indexOf(version) > 0).toBe(true)
 
    describe "when the action is taken", ->
      it "should fire the `application:install-update` IPC event", ->
        Actions.notificationActionTaken({notification: {}, action: {id: 'release-bar:install-update'}})
        expect(Array.prototype.slice.call(ipcSendArgs)).toEqual(['command', 'application:install-update'])

