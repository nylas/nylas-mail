_ = require 'underscore'

# Public: To make specs easier to test, we make all asynchronous behavior
# actually synchronous. We do this by overriding all global timeout and
# Promise functions.
#
# You must now manually call `advanceClock()` in order to move the "clock"
# forward.
class TimeOverride

  @advanceClock = (delta=1) =>
    @now += delta
    callbacks = []

    @timeouts ?= []
    @timeouts = @timeouts.filter ([id, strikeTime, callback]) =>
      if strikeTime <= @now
        callbacks.push(callback)
        false
      else
        true

    callback() for callback in callbacks

  @resetTime = =>
    @now = 0
    @timeoutCount = 0
    @intervalCount = 0
    @timeouts = []
    @intervalTimeouts = {}
    @originalPromiseScheduler = null

  @enableSpies = =>
    window.advanceClock = @advanceClock

    window.originalSetInterval = window.setInterval
    spyOn(window, "setTimeout").andCallFake @_fakeSetTimeout
    spyOn(window, "clearTimeout").andCallFake @_fakeClearTimeout
    spyOn(window, "setInterval").andCallFake @_fakeSetInterval
    spyOn(window, "clearInterval").andCallFake @_fakeClearInterval
    spyOn(_._, "now").andCallFake => @now

    # spyOn(Date, "now").andCallFake => @now
    # spyOn(Date.prototype, "getTime").andCallFake => @now

    @_setPromiseScheduler()

  @_setPromiseScheduler: =>

    # Make Bluebird use setTimeout so that it hooks into our stubs, and you
    # can advance promises using `advanceClock()`. To avoid breaking any
    # specs that `dont` manually call advanceClock, call it automatically on
    # the next tick.
    @originalPromiseScheduler ?= Promise.setScheduler (fn) =>
      setTimeout(fn, 0)
      process.nextTick =>
        @advanceClock(1)

  @disableSpies = =>
    window.advanceClock = null

    jasmine.unspy(window, 'setTimeout')
    jasmine.unspy(window, 'clearTimeout')
    jasmine.unspy(window, 'setInterval')
    jasmine.unspy(window, 'clearInterval')

    jasmine.unspy(_._, "now")

    Promise.setScheduler(@originalPromiseScheduler) if @originalPromiseScheduler
    @originalPromiseScheduler = null

  @resetSpyData = ->
    window.setTimeout.reset?()
    window.clearTimeout.reset?()
    window.setInterval.reset?()
    window.clearInterval.reset?()
    Date.now.reset?()
    Date.prototype.getTime.reset?()

  @_fakeSetTimeout = (callback, ms) =>
    id = ++@timeoutCount
    @timeouts.push([id, @now + ms, callback])
    id

  @_fakeClearTimeout = (idToClear) =>
    @timeouts ?= []
    @timeouts = @timeouts.filter ([id]) -> id != idToClear

  @_fakeSetInterval = (callback, ms) =>
    id = ++@intervalCount
    action = ->
      callback()
      @intervalTimeouts[id] = @_fakeSetTimeout(action, ms)
    @intervalTimeouts[id] = @_fakeSetTimeout(action, ms)
    id

  @_fakeClearInterval = (idToClear) =>
    @_fakeClearTimeout(@intervalTimeouts[idToClear])

module.exports = TimeOverride
