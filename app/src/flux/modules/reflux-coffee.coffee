EventEmitter = require('events').EventEmitter

callbackName = (string) ->
  "on"+string.charAt(0).toUpperCase()+string.slice(1)


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

    validateListening: (listenable) ->
      if listenable == this
        return 'Listener is not able to listen to itself'
      if not (listenable.listen instanceof Function)
        console.log require('util').inspect(listenable)
        console.log((new Error()).stack)
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

      resolvedCallback = @[callback] or callback
      if not resolvedCallback
        throw new Error("@listenTo called with undefined callback")
      desub = listenable.listen(resolvedCallback, this)

      unsubscriber = ->
        index = subs.indexOf(subscriptionobj)
        if index == -1
          throw new Error('Tried to remove listen already gone from subscriptions list!')
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
          if subs.indexOf(sub) != -1
            throw new Error('Failed to remove listen from subscriptions list!')
          return true
        i++
      false

    stopListeningToAll: ->
      remaining = undefined
      subs = @subscriptions or []
      while remaining = subs.length
        subs[0].stop()
        if subs.length != remaining - 1
          throw new Error('Failed to remove listen from subscriptions list!')
      return

    fetchInitialState: (listenable, defaultCallback) ->
      defaultCallback = defaultCallback and @[defaultCallback] or defaultCallback
      me = this
      if defaultCallback instanceof Function and listenable.getInitialState instanceof Function
        data = listenable.getInitialState()
        if data and data.then instanceof Function
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
      @_emitter.setMaxListeners(100)

    listen: (callback, bindContext) ->
      if not callback
        throw new Error("@listen called with undefined callback")

      @setupEmitter()
      bindContext ?= @
      aborted = false
      eventHandler = (args) ->
        return if aborted
        callback.apply(bindContext, args)
      @_emitter.addListener('trigger', eventHandler)
      return =>
        aborted = true
        @_emitter.removeListener('trigger', eventHandler)

    trigger: ->
      @setupEmitter()
      @_emitter.emit('trigger', arguments)
