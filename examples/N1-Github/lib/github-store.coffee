_ = require 'underscore'
NylasStore = require 'nylas-store'
{MessageStore} = require 'nylas-exports'

###
The GithubStore is responsible for preparing the data we need (in this case just the Github url) for the `ViewOnGithubButton` to display.

When thinking how to build this store, the first consideration was where we'd get our data. The next consideration was when that data would be available.

This Store simply looks for the presence of a "view it on github" link in an email from Github.

This means we're going to need a message body to parse. Furthermore, we're going to need the message bodies of just the thread the user's currently looking at.

We could have gone at this a couple ways. One way would be to grab the messages for the currently focused thread straight from the Database.

We need to be careful since the message bodies (which could be HUGE) are stored in a different table then the message metadata.

Luckily, after looking through the available stores, we see that the {MessageStore} does all of this lookup logic for us. It even already listens to whenever the thread changes and loads only the correct messages (and their bodies) into its cache.

Instead of writing the Database lookup code ourselves, and creating another, potentially very expensive query, we'll use the {MessageStore} instead.

This also means we need to know when the {MessageStore} changes. It'll change under a variety of circumstances, but the most common one will be when the currently focused thread changes.

We setup the listener for that change in our constructor and provide a callback.

Our callback, `_onMessageStoreChanged`, will grab the messages, check if they're relevant (they come from Github), and parse our the links, if any.

It will then cache that result in `this._link`, and finally `trigger()` to let the `ViewOnGithubButton` know it's time to fetch new data.
###
class GithubStore extends NylasStore

  # It's very common practive for {NylasStore}s to listen to other sources
  # of data upon their construction. Since Stores are singletons and
  # constructed only once during the initial `require`, there is no
  # teardown step to turn off listeners.
  constructor: ->
    @listenTo MessageStore, @_onMessageStoreChanged

  # This is the only public method on `GithubStore` and it's read only.
  # All {NylasStore}s ONLY have reader methods. No setter methods. Use an
  # `Action` instead!
  #
  # This is the computed & cached value that our `ViewOnGithubButton` will
  # render.
  link: -> @_link

  #### "Private" methods ####

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

    # Yep!, this is a very quick and dirty way to figure out what object
    # on Github we're referring to.
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

# IMPORTANT NOTE:
#
# All {NylasStore}s are constructed upon their first `require` by another
# module.  Since `require` is cached, they are only constructed once and
# are therefore singletons.
module.exports = new GithubStore()
