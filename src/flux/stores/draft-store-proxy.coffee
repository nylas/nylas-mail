Message = require '../models/message'
Actions = require '../actions'
DatabaseStore = require './database-store'

{Listener, Publisher} = require '../modules/reflux-coffee'
SyncbackDraftTask = require '../tasks/syncback-draft'
CoffeeHelpers = require '../coffee-helpers'

_ = require 'underscore'

###
Public: As the user interacts with the draft, changes are accumulated in the
DraftChangeSet associated with the store proxy. The DraftChangeSet does two things:

1. It debounces changes and calls Actions.saveDraft() at a reasonable interval.

2. It exposes `applyToModel`, which allows you to optimistically apply changes
  to a draft object. When the proxy vends the draft, it passes it through this
  function to apply uncommitted changes. This means the Draft provided by the
  DraftStoreProxy will always relfect recent changes, even though they're
  written to the database intermittently.

Section: Drafts
###
class DraftChangeSet
  constructor: (@_onTrigger, @_onCommit) ->
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

  add: (changes, {immediate, silent}={}) =>
    @_pending = _.extend(@_pending, changes)
    @_pending['pristine'] = false
    @_onTrigger() unless silent
    if immediate
      @commit()
    else
      clearTimeout(@_timer) if @_timer
      @_timer = setTimeout(@commit, 5000)

  # If force is true, then we'll always run the `_onCommit` callback
  # regardless if there are _pending changes or not
  commit: ({force}={}) =>
    @_commitChain = @_commitChain.finally =>

      if not force and Object.keys(@_pending).length is 0
        return Promise.resolve(true)

      @_saving = @_pending
      @_pending = {}
      return @_onCommit().then =>
        @_saving = {}

    return @_commitChain

  applyToModel: (model) =>
    if model
      model.fromJSON(@_saving)
      model.fromJSON(@_pending)
    model

###
Public: DraftStoreProxy is a small class that makes it easy to implement components
that display Draft objects or allow for interactive editing of Drafts.

1. It synchronously provides an instance of a draft via `draft()`, and
   triggers whenever that draft instance has changed.

2. It provides an interface for modifying the draft that transparently
   batches changes, and ensures that the draft provided via `draft()`
   always has pending changes applied.

Section: Drafts
###
class DraftStoreProxy
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: (@draftClientId, draft = null) ->
    DraftStore = require './draft-store'
    @listenTo DraftStore, @_onDraftChanged

    @_draft = false
    @_draftPristineBody = null
    @_destroyed = false

    @changes = new DraftChangeSet(@_changeSetTrigger, @_changeSetCommit)

    if draft
      @_setDraft(draft)
      @_draftPromise = Promise.resolve(@)

    @prepare()

  # Public: Returns the draft object with the latest changes applied.
  #
  draft: ->
    @changes.applyToModel(@_draft)
    @_draft

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
      @_setDraft(draft)
      Promise.resolve(@)
    @_draftPromise

  teardown: ->
    @stopListeningToAll()
    @changes.teardown()
    @_destroyed = true

  _setDraft: (draft) ->
    if !draft.body?
      throw new Error("DraftStoreProxy._setDraft - new draft has no body!")

    # We keep track of the draft's initial body if it's pristine when the editing
    # session begins. This initial value powers things like "are you sure you want
    # to send with an empty body?"
    if draft.pristine
      @_draftPristineBody = draft.body
    @_draft = draft
    @trigger()

  _onDraftChanged: (change) ->
    return if not change?
    # We don't accept changes unless our draft object is loaded
    return unless @_draft

    # Is this change an update to our draft?
    myDrafts = _.filter(change.objects, (obj) => obj.clientId is @_draft.clientId)
    if myDrafts.length > 0
      @_draft = _.extend @_draft, _.last(myDrafts)
      @trigger()

  _changeSetTrigger: =>
    return if @_destroyed
    if !@_draft
      throw new Error("DraftChangeSet was modified before the draft was prepared.")
    @trigger()

  _changeSetCommit: =>
    if @_destroyed or not @_draft
      return Promise.resolve(true)

    # Set a variable here to protect againg @_draft getting set from
    # underneath us
    inMemoryDraft = @_draft

    DatabaseStore.atomically =>
      DatabaseStore.findBy(Message, clientId: inMemoryDraft.clientId).then (draft) =>
        # This can happen if we get a "delete" delta, or something else
        # strange happens. In this case, we'll use the @_draft we have in
        # memory to apply the changes to. On the `persistModel` in the
        # next line it will save the correct changes. The
        # `SyncbackDraftTask` may then fail due to differing Ids not
        # existing, but if this happens it'll 404 and recover gracefully
        # by creating a new draft
        if not draft then draft = inMemoryDraft

        updatedDraft = @changes.applyToModel(draft)
        return DatabaseStore.persistModel(updatedDraft).then =>
          Actions.queueTask(new SyncbackDraftTask(@draftClientId))



DraftStoreProxy.DraftChangeSet = DraftChangeSet

module.exports = DraftStoreProxy
