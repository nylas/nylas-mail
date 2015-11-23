_ = require "underscore"
crypto = require "crypto"
MessageUtils = require '../models/message-utils'
MessageStore = require './message-store'

MessageBodyWidth = 740

class MessageBodyProcessor

  constructor: ->
    @_subscriptions = []
    @resetCache()

  resetCache: ->
    # Store an object for recently processed items. Put the item reference into
    # both data structures so we can access it in O(1) and also delete in O(1)
    @_recentlyProcessedA = []
    @_recentlyProcessedD = {}
    for {message, callback} in @_subscriptions
      callback(@process(message))

  # It's far safer to key off the hash of the body then the [id, version]
  # pair. This is because it's theoretically possible for the body to
  # change without the version updating. When drafts sent N1 used to
  # optimistically display the message before the latest changes
  # persisted.
  _key: (message) ->
    return message.id + crypto.createHash('md5').update(message.body ? "").digest('hex')

  version: ->
    @_version

  processAndSubscribe: (message, callback) =>
    callback(@process(message))
    sub = {message, callback}
    @_subscriptions.push(sub)
    return =>
      @_subscriptions.splice(@_subscriptions.indexOf(sub), 1)

  process: (message) =>
    body = message.body
    return "" unless _.isString message.body

    key = @_key(message)
    if @_recentlyProcessedD[key]
      return @_recentlyProcessedD[key].body

    # Give each extension the message object to process the body, but don't
    # allow them to modify anything but the body for the time being.
    for extension in MessageStore.extensions()
      continue unless extension.formatMessageBody
      virtual = message.clone()
      virtual.body = body
      extension.formatMessageBody(virtual)
      body = virtual.body

    # Find inline images and give them a calculated CSS height based on
    # html width and height, when available. This means nothing changes size
    # as the image is loaded, and we can estimate final height correctly.
    # Note that MessageBodyWidth must be updated if the UI is changed!

    while (result = MessageUtils.cidRegex.exec(body)) isnt null
      imgstart = body.lastIndexOf('<', result.index)
      imgend = body.indexOf('/>', result.index)

      if imgstart != -1 and imgend > imgstart
        imgtag = body.substr(imgstart, imgend - imgstart)
        width = imgtag.match(/width[ ]?=[ ]?['"]?(\d*)['"]?/)?[1]
        height = imgtag.match(/height[ ]?=[ ]?['"]?(\d*)['"]?/)?[1]
        if width and height
          scale = Math.min(1, MessageBodyWidth / width)
          style = " style=\"height:#{height * scale}px;\" "
          body = body.substr(0, imgend) + style + body.substr(imgend)

    @addToCache(key, body)
    body

  addToCache: (key, body) ->
    if @_recentlyProcessedA.length > 50
      removed = @_recentlyProcessedA.pop()
      delete @_recentlyProcessedD[removed.key]
    item = {key, body}
    @_recentlyProcessedA.unshift(item)
    @_recentlyProcessedD[key] = item

module.exports = new MessageBodyProcessor()
