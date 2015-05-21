Message = require '../models/message'
Actions = require '../actions'

{Listener, Publisher} = require '../modules/reflux-coffee'
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
  constructor: (@localId, @_onChange) ->
    @reset()

  reset: ->
    @_pending = {}
    clearTimeout(@_timer) if @_timer
    @_timer = null

  add: (changes, immediate) =>
    @_pending = _.extend(@_pending, changes)
    @_pending['pristine'] = false
    @_onChange()
    if immediate
      @commit()
    else
      clearTimeout(@_timer) if @_timer
      @_timer = setTimeout(@commit, 5000)

  commit: =>
    if Object.keys(@_pending).length is 0
      return Promise.resolve(true)

    DatabaseStore = require './database-store'
    DatabaseStore.findByLocalId(Message, @localId).then (draft) =>
      if not draft
        throw new Error("Tried to commit a draft that had already been removed from the database. DraftId: #{@localId}")
      draft = @applyToModel(draft)
      DatabaseStore.persistModel(draft).then =>
        @_pending = {}

  applyToModel: (model) =>
    model.fromJSON(@_pending) if model
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

  constructor: (@draftLocalId) ->
    DraftStore = require './draft-store'

    @listenTo DraftStore, @_onDraftChanged
    @listenTo Actions.didSwapModel, @_onDraftSwapped

    @_draft = false
    @_draftPromise = null
    @changes = new DraftChangeSet @draftLocalId, =>
      if !@_draft
        throw new Error("DraftChangeSet was modified before the draft was prepared.")
      @trigger()

    @prepare().catch (error) ->
      console.error(error)
      console.error(error.stack)
      throw new Error("DraftStoreProxy prepare() failed with error #{error.toString()}.")

  draft: ->
    @changes.applyToModel(@_draft)
    @_draft

  prepare: ->
    @_draftPromise ?= new Promise (resolve, reject) =>
      DatabaseStore = require './database-store'
      DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
        if not draft
          reject(new Error("Can't prepare. Draft is null"))
        else
          @_setDraft(draft)
          resolve(@)
      .catch(reject)
    @_draftPromise

  cleanup: ->
    @stopListeningToAll()

  _setDraft: (draft) ->
    if !draft.body?
      throw new Error("DraftStoreProxy._setDraft - new draft has no body!")
    @_draft = draft
    @trigger()

  _onDraftChanged: (change) ->
    return if not change?
    # We don't accept changes unless our draft object is loaded
    return unless @_draft

    # Is this change an update to our draft?
    myDraft = _.find(change.objects, (obj) => obj.id == @_draft.id)
    if myDraft
      @_draft = _.extend @_draft, myDraft
      @trigger()

  _onDraftSwapped: (change) ->
    # A draft was saved with a new ID. Since we use the draft ID to
    # watch for changes to our draft, we need to pull again using our
    # localId.
    if change.oldModel.id is @_draft.id
      @_setDraft(change.newModel)


module.exports = DraftStoreProxy
