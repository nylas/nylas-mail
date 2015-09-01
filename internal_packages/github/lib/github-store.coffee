_ = require 'underscore'
NylasStore = require 'nylas-store'
{MessageStore} = require 'nylas-exports'

class GithubStore extends NylasStore
  constructor: ->
    @listenTo MessageStore, @_onMessageStoreChanged

  link: -> @_link

  _onMessageStoreChanged: ->
    return unless MessageStore.threadId()
    itemIds = _.pluck(MessageStore.items(), "id")
    return if itemIds.length is 0 or _.isEqual(itemIds, @_lastItemIds)
    @_lastItemIds = itemIds
    @_link = if @_isRelevantThread() then @_findGitHubLink() else null
    @trigger()

  _findGitHubLink: ->
    msg = MessageStore.items()[0]
    if not msg.body
      # The msg body may be null if it's collapsed. In that case, use the
      # last message. This may be less relaiable since the last message
      # might be a side-thread that doesn't contain the link in the quoted
      # text.
      msg = _.last(MessageStore.items())
    # https://regex101.com/r/aW8bI4/2
    re = /<a.*?href=['"](.*?)['"].*?view.*?it.*?on.*?github.*?\/a>/gmi
    firstMatch = re.exec(msg.body)
    if firstMatch
      link = firstMatch[1] # [0] is the full match and [1] is the matching group
      return link
    else return null

  _isRelevantThread: ->
    _.any (MessageStore.thread().participants ? []), (contact) ->
      (/@github\.com/gi).test(contact.email)

module.exports = new GithubStore()
