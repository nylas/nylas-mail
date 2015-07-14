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
    @_commitChain = Promise.resolve()
    @reset()

  reset: ->
    @_pending = {}
    @_saving = {}
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
    @_commitChain = @_commitChain.then =>
      if Object.keys(@_pending).length is 0
        return Promise.resolve(true)

      DatabaseStore = require './database-store'
      return DatabaseStore.findByLocalId(Message, @localId).then (draft) =>
        if not draft
          throw new Error("Tried to commit a draft that had already been removed from the database. DraftId: #{@localId}")
        @_saving = @_pending
        @_pending = {}
        draft = @applyToModel(draft)
        return DatabaseStore.persistModel(draft).then =>
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

  constructor: (@draftLocalId, draft = null) ->
    DraftStore = require './draft-store'

    @listenTo DraftStore, @_onDraftChanged
    @listenTo Actions.didSwapModel, @_onDraftSwapped

    @_draft = false
    @_draftPristineBody = null

    @changes = new DraftChangeSet @draftLocalId, =>
      if !@_draft
        throw new Error("DraftChangeSet was modified before the draft was prepared.")
      @trigger()

    if draft
      @_setDraft(draft)
      @_draftPromise = Promise.resolve(@)

    @prepare().catch (error) ->
      console.error(error)
      console.error(error.stack)
      throw new Error("DraftStoreProxy prepare() failed with error #{error.toString()}.")

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
    myDrafts = _.filter(change.objects, (obj) => obj.id == @_draft.id)

    if myDrafts.length > 0
      @_draft = _.extend @_draft, _.last(myDrafts)
      @trigger()

  _onDraftSwapped: (change) ->
    # A draft was saved with a new ID. Since we use the draft ID to
    # watch for changes to our draft, we need to pull again using our
    # localId.
    if change.oldModel.id is @_draft.id
      @_setDraft(change.newModel)


module.exports = DraftStoreProxy
