Reflux = require 'reflux'
_ = require 'underscore-plus'
{File,
 DatabaseStore,
 DatabaseView} = require 'inbox-exports'

module.exports =
FileListStore = Reflux.createStore
  init: ->
    @listenTo DatabaseStore, @_onDataChanged

    @_view = new DatabaseView(File, matchers: [File.attributes.filename.not('')])
    @listenTo @_view, => @trigger({})

  view: ->
    @_view

  _onDataChanged: (change) ->
    return unless change.objectClass is File.name
    @_view.invalidate({shallow: true, changed: change.objects})
