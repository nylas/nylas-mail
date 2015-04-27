_ = require('underscore-plus')
EventEmitter = require('events').EventEmitter

###*
# Extract child listenables from a parent from their
# children property and return them in a keyed Object
#
# @param {Object} listenable The parent listenable
###

mapChildListenables = (listenable) ->
  i = 0
  children = {}
  childName = undefined
  while i < (listenable.children or []).length
    childName = listenable.children[i]
    if listenable[childName]
      children[childName] = listenable[childName]
    ++i
  children

###*
# Make a flat dictionary of all listenables including their
# possible children (recursively), concatenating names in camelCase.
#
# @param {Object} listenables The top-level listenables
###

flattenListenables = (listenables) ->
  flattened = {}
  for key of listenables
    listenable = listenables[key]
    childMap = mapChildListenables(listenable)
    # recursively flatten children
    children = flattenListenables(childMap)
    # add the primary listenable and chilren
    flattened[key] = listenable
    for childKey of children
      childListenable = children[childKey]
      flattened[key + _.capitalize(childKey)] = childListenable
  flattened


module.exports =

  Listener:
    hasListener: (listenable) ->
      i = 0
      j = undefined
      listener = undefined
      listenables = undefined
      while i < (@subscriptions or []).length
        listenables = [].concat(@subscriptions[i].listenable)
        j = 0
        while j < listenables.length
          listener = listenables[j]
          if listener == listenable or listener.hasListener and listener.hasListener(listenable)
            return true
          j++
        ++i
      false

    listenToMany: (listenables) ->
      allListenables = flattenListenables(listenables)
      for key of allListenables
        cbname = _.callbackName(key)
        localname = if @[cbname] then cbname else if @[key] then key else undefined
        if localname
          @listenTo allListenables[key], localname, @[cbname + 'Default'] or @[localname + 'Default'] or localname
      return

    validateListening: (listenable) ->
      if listenable == this
        return 'Listener is not able to listen to itself'
      if !_.isFunction(listenable.listen)
        return listenable + ' is missing a listen method'
      if listenable.hasListener and listenable.hasListener(this)
        return 'Listener cannot listen to this listenable because of circular loop'
      return

    listenTo: (listenable, callback, defaultCallback) ->
      desub = undefined
      unsubscriber = undefined
      subscriptionobj = undefined
      subs = @subscriptions = @subscriptions or []
      err = @validateListening(listenable)
      throw err if err
      @fetchInitialState listenable, defaultCallback
      desub = listenable.listen(@[callback] or callback, this)

      unsubscriber = ->
        index = subs.indexOf(subscriptionobj)
        _.throwIf index == -1, 'Tried to remove listen already gone from subscriptions list!'
        subs.splice index, 1
        desub()
        return

      subscriptionobj =
        stop: unsubscriber
        listenable: listenable
      subs.push subscriptionobj
      subscriptionobj

    stopListeningTo: (listenable) ->
      sub = undefined
      i = 0
      subs = @subscriptions or []
      while i < subs.length
        sub = subs[i]
        if sub.listenable == listenable
          sub.stop()
          _.throwIf subs.indexOf(sub) != -1, 'Failed to remove listen from subscriptions list!'
          return true
        i++
      false

    stopListeningToAll: ->
      remaining = undefined
      subs = @subscriptions or []
      while remaining = subs.length
        subs[0].stop()
        _.throwIf subs.length != remaining - 1, 'Failed to remove listen from subscriptions list!'
      return

    fetchInitialState: (listenable, defaultCallback) ->
      defaultCallback = defaultCallback and @[defaultCallback] or defaultCallback
      me = this
      if _.isFunction(defaultCallback) and _.isFunction(listenable.getInitialState)
        data = listenable.getInitialState()
        if data and _.isFunction(data.then)
          data.then ->
            defaultCallback.apply me, arguments
            return
        else
          defaultCallback.call this, data
      return


  Publisher:
    setupEmitter: ->
      return if @_emitter
      @_emitter ?= new EventEmitter()
      @_emitter.setMaxListeners(25)

    listen: (callback, bindContext) ->
      @setupEmitter()
      bindContext ?= @
      aborted = false
      eventHandler = ->
        return if aborted
        callback.apply(bindContext, arguments)
      @_emitter.addListener('trigger', eventHandler)
      return =>
        aborted = true
        @_emitter.removeListener('trigger', eventHandler)

    trigger: (arg) ->
      @setupEmitter()
      @_emitter.emit('trigger', arg)
