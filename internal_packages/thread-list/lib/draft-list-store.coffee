Reflux = require 'reflux'
_ = require 'underscore-plus'
{Message,
 DatabaseStore,
 DatabaseView} = require 'inbox-exports'

module.exports =
DraftListStore = Reflux.createStore
  init: ->
    @listenTo DatabaseStore, @_onDataChanged

    @_view = new DatabaseView Message,
      matchers: [Message.attributes.draft.equal(true)],
      includes: [Message.attributes.body]

    @listenTo @_view, => @trigger({})

  view: ->
    @_view

  _onDataChanged: (change) ->
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft
    @_view.invalidate()
