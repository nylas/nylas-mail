Message = require('../models/message').default
Actions = require '../actions'
DatabaseStore = require './database-store'
ExtensionRegistry = require('../../extension-registry')
{Listener, Publisher} = require '../modules/reflux-coffee'
SyncbackDraftTask = require('../tasks/syncback-draft-task').default
CoffeeHelpers = require '../coffee-helpers'
DraftStore = null

_ = require 'underscore'

MetadataChangePrefix = 'metadata.'

###
Public: As the user interacts with the draft, changes are accumulated in the
DraftChangeSet associated with the store session. The DraftChangeSet does two things:

1. It debounces changes and calls Actions.saveDraft() at a reasonable interval.

2. It exposes `applyToModel`, which allows you to optimistically apply changes
  to a draft object. When the session vends the draft, it passes it through this
  function to apply uncommitted changes. This means the Draft provided by the
  DraftEditingSession will always relfect recent changes, even though they're
  written to the database intermittently.

Section: Drafts
###
class DraftChangeSet
  constructor: (@_onAltered, @_onCommit) ->
    @_commitChain = Promise.resolve()
    @_pending = {}
    @_saving = {}
    @_timer = null

  teardown: ->
    @_pending = {}
    @_saving = {}
    if @_timer
      clearTimeout(@_timer)
      @_timer = null

  add: (changes, {doesNotAffectPristine}={}) =>
    @_pending = _.extend(@_pending, changes)
    @_pending['pristine'] = false unless doesNotAffectPristine
    @_onAltered()

    clearTimeout(@_timer) if @_timer
    @_timer = setTimeout(@commit, 10000)

  addPluginMetadata: (pluginId, metadata) =>
    changes = {}
    changes["#{MetadataChangePrefix}#{pluginId}"] = metadata
    @add(changes, {doesNotAffectPristine: true})

  commit: ({noSyncback}={}) =>
    @_commitChain = @_commitChain.finally =>
      if Object.keys(@_pending).length is 0
        return Promise.resolve(true)

      @_saving = @_pending
      @_pending = {}
      return @_onCommit({noSyncback}).then =>
        @_saving = {}

    return @_commitChain

  applyToModel: (model) =>
    if model
      changesToApply = _.pairs(@_saving).concat(_.pairs(@_pending))
      for [key, val] in changesToApply
        if key.startsWith(MetadataChangePrefix)
          model.applyPluginMetadata(key.split(MetadataChangePrefix).pop(), val)
        else
          model[key] = val
    model

###
Public: DraftEditingSession is a small class that makes it easy to implement components
that display Draft objects or allow for interactive editing of Drafts.

1. It synchronously provides an instance of a draft via `draft()`, and
   triggers whenever that draft instance has changed.

2. It provides an interface for modifying the draft that transparently
   batches changes, and ensures that the draft provided via `draft()`
   always has pending changes applied.

Section: Drafts
###
class DraftEditingSession
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: (@draftClientId, draft = null) ->
    DraftStore ?= require './draft-store'
    @listenTo DraftStore, @_onDraftChanged

    @_draft = false
    @_draftPristineBody = null
    @_destroyed = false

    @changes = new DraftChangeSet(@_changeSetAltered, @_changeSetCommit)

    if draft
      @_draftPromise = @_setDraft(draft)

    @prepare()

  # Public: Returns the draft object with the latest changes applied.
  #
  draft: ->
    return null if not @_draft
    @changes.applyToModel(@_draft)
    @_draft.clone()

  # Public: Returns the initial body of the draft when it was pristine, or null if the
  # draft was never pristine in this editing session. Useful for determining if the
  # body is still in an unchanged / empty state.
  #
  draftPristineBody: ->
    @_draftPristineBody

  prepare: ->
    @_draftPromise ?= DatabaseStore.findBy(Message, clientId: @draftClientId).include(Message.attributes.body).then (draft) =>
      return Promise.reject(new Error("Draft has been destroyed.")) if @_destroyed
      return Promise.reject(new Error("Assertion Failure: Draft #{@draftClientId} not found.")) if not draft
      return @_setDraft(draft)

  teardown: ->
    @stopListeningToAll()
    @changes.teardown()
    @_destroyed = true

  _setDraft: (draft) ->
    if !draft.body?
      throw new Error("DraftEditingSession._setDraft - new draft has no body!")

    # We keep track of the draft's initial body if it's pristine when the editing
    # session begins. This initial value powers things like "are you sure you want
    # to send with an empty body?"
    if draft.pristine
      @_draftPristineBody = draft.body

    # Reverse draft transformations performed by third-party plugins when the draft
    # was last saved to disk
    return Promise.each ExtensionRegistry.Composer.extensions(), (ext) ->
      if ext.applyTransformsToDraft and ext.unapplyTransformsToDraft
        Promise.resolve(ext.unapplyTransformsToDraft({draft})).then (untransformed) ->
          unless untransformed is 'unnecessary'
            draft = untransformed
    .then =>
      @_draft = draft
      @trigger()
      Promise.resolve(@)

  _onDraftChanged: (change) ->
    return if not change?

    # We don't accept changes unless our draft object is loaded
    return unless @_draft

    # If our draft has been changed, only accept values which are present.
    # If `body` is undefined, assume it's not loaded. Do not overwrite old body.
    nextDraft = _.filter(change.objects, (obj) => obj.clientId is @_draft.clientId).pop()
    if nextDraft
      nextValues = {}
      for key, attr of Message.attributes
        continue if key is 'id'
        continue if nextDraft[key] is undefined
        nextValues[key] = nextDraft[key]
      @_setDraft(Object.assign(new Message(), @_draft, nextValues))
      @trigger()

  _changeSetAltered: =>
    return if @_destroyed
    if !@_draft
      throw new Error("DraftChangeSet was modified before the draft was prepared.")

    @changes.applyToModel(@_draft)
    @trigger()

  _changeSetCommit: ({noSyncback}={}) =>
    if @_destroyed or not @_draft
      return Promise.resolve(true)

    # Set a variable here to protect againg @_draft getting set from
    # underneath us
    inMemoryDraft = @_draft

    DatabaseStore.inTransaction (t) =>
      t.findBy(Message, clientId: inMemoryDraft.clientId).include(Message.attributes.body).then (draft) =>
        # This can happen if we get a "delete" delta, or something else
        # strange happens. In this case, we'll use the @_draft we have in
        # memory to apply the changes to. On the `persistModel` in the
        # next line it will save the correct changes. The
        # `SyncbackDraftTask` may then fail due to differing Ids not
        # existing, but if this happens it'll 404 and recover gracefully
        # by creating a new draft
        draft ?= inMemoryDraft
        updatedDraft = @changes.applyToModel(draft)
        return t.persistModel(updatedDraft)

    .then =>
      return if noSyncback
      # We have temporarily disabled the syncback of most drafts to user's mail
      # providers, due to a number of issues in the sync-engine that we're still
      # firefighting.
      #
      # For now, drafts are only synced when you choose "Send Later", and then
      # once they have a serverId we sync them periodically here.
      #
      return unless @_draft.serverId
      Actions.ensureDraftSynced(@draftClientId)


DraftEditingSession.DraftChangeSet = DraftChangeSet

module.exports = DraftEditingSession
