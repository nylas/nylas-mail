Message = require('../models/message').default
Actions = require('../actions').default
NylasAPIHelpers = require '../nylas-api-helpers'
AccountStore = require('./account-store').default
ContactStore = require './contact-store'
DatabaseStore = require('./database-store').default
UndoStack = require('../../undo-stack').default
DraftHelpers = require('../stores/draft-helpers').default
ExtensionRegistry = require '../../registries/extension-registry'
{Listener, Publisher} = require '../modules/reflux-coffee'
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
  @include: CoffeeHelpers.includeModule
  @include Publisher

  constructor: (@callbacks) ->
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
    @callbacks.onWillAddChanges(changes)
    @_pending = _.extend(@_pending, changes)
    @_pending.pristine = false unless doesNotAffectPristine
    @callbacks.onDidAddChanges(changes)

    clearTimeout(@_timer) if @_timer
    @_timer = setTimeout(@commit, 10000)

  addPluginMetadata: (pluginId, metadata) =>
    changes = {}
    changes["#{MetadataChangePrefix}#{pluginId}"] = metadata
    @add(changes, {doesNotAffectPristine: true})

  commit: () =>
    clearTimeout(@_timer) if @_timer
    @_commitChain = @_commitChain.finally =>
      if Object.keys(@_pending).length is 0
        return Promise.resolve(true)

      @_saving = @_pending
      @_pending = {}
      return @callbacks.onCommit().then =>
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
    DraftStore ?= require('./draft-store').default
    @listenTo DraftStore, @_onDraftChanged

    @_draft = false
    @_draftPristineBody = null
    @_destroyed = false
    @_undoStack = new UndoStack()

    @changes = new DraftChangeSet({
      onWillAddChanges: @changeSetWillAddChanges
      onDidAddChanges: @changeSetDidAddChanges
      onCommit: @changeSetCommit
    })

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

  validateDraftForSending: =>
    warnings = []
    errors = []
    allRecipients = [].concat(@_draft.to, @_draft.cc, @_draft.bcc)
    bodyIsEmpty = @_draft.body is @draftPristineBody() or @_draft.body is "<br>"
    forwarded = DraftHelpers.isForwardedMessage(@_draft)
    hasAttachment = @_draft.files?.length > 0 or @_draft.uploads?.length > 0

    for contact in allRecipients
      if not ContactStore.isValidContact(contact)
        errors.push("#{contact.email} is not a valid email address - please remove or edit it before sending.")

    if allRecipients.length is 0
      errors.push('You need to provide one or more recipients before sending the message.')

    if errors.length > 0
      return {errors, warnings}

    if @_draft.subject.length is 0
      warnings.push('without a subject line')

    if DraftHelpers.messageMentionsAttachment(@_draft) and not hasAttachment
      warnings.push('without an attachment')

    if bodyIsEmpty and not forwarded and not hasAttachment
      warnings.push('without a body')

    ## Check third party warnings added via Composer extensions
    for extension in ExtensionRegistry.Composer.extensions()
      continue if not extension.warningsForSending
      warnings = warnings.concat(extension.warningsForSending({draft: @_draft}))

    return {errors, warnings}

  # This function makes sure the draft is attached to a valid account, and changes
  # it's accountId if the from address does not match the account for the from
  # address
  #
  # If the account is updated it makes a request to delete the draft with the
  # old accountId
  ensureCorrectAccount: =>
    account = AccountStore.accountForEmail(@_draft.from[0].email)
    if !account
      return Promise.reject(new Error("DraftEditingSession::ensureCorrectAccount - you can only send drafts from a configured account."))

    if account.id isnt @_draft.accountId
      NylasAPIHelpers.makeDraftDeletionRequest(@_draft)
      @changes.add({
        accountId: account.id,
        version: null,
        serverId: null,
        threadId: null,
        replyToMessageId: null,
      })
      return @changes.commit()
      .thenReturn(@)
    return Promise.resolve(@)

  _setDraft: (draft) ->
    if !draft.body?
      throw new Error("DraftEditingSession._setDraft - new draft has no body!")

    extensions = ExtensionRegistry.Composer.extensions()

    # Run `extensions[].unapplyTransformsForSending`
    fragment = document.createDocumentFragment()
    draftBodyRootNode = document.createElement('root')
    fragment.appendChild(draftBodyRootNode)
    draftBodyRootNode.innerHTML = draft.body

    return Promise.each extensions, (ext) ->
      if ext.applyTransformsForSending and ext.unapplyTransformsForSending
        Promise.resolve(ext.unapplyTransformsForSending({
          draftBodyRootNode: draftBodyRootNode,
          draft: draft}))
    .then =>
      draft.body = draftBodyRootNode.innerHTML
      @_draft = draft

      # We keep track of the draft's initial body if it's pristine when the editing
      # session begins. This initial value powers things like "are you sure you want
      # to send with an empty body?"
      if draft.pristine
        @_draftPristineBody = draft.body
        @_undoStack.save(@_snapshot())

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

  changeSetCommit: () =>
    if @_destroyed or not @_draft
      return Promise.resolve(true)

    # Set a variable here to protect againg @_draft getting set from
    # underneath us
    inMemoryDraft = @_draft

    DatabaseStore.inTransaction (t) =>
      t.findBy(Message, clientId: inMemoryDraft.clientId).include(Message.attributes.body).then (draft) =>
        draft ?= inMemoryDraft
        updatedDraft = @changes.applyToModel(draft)
        return t.persistModel(updatedDraft)

  # Undo / Redo

  changeSetWillAddChanges: (changes) =>
    return if @_restoring
    hasBeen300ms = Date.now() - @_lastAddTimestamp > 300
    hasChangedFields = !_.isEqual(Object.keys(changes), @_lastChangedFields)

    @_lastChangedFields = Object.keys(changes)
    @_lastAddTimestamp = Date.now()
    if hasBeen300ms || hasChangedFields
      @_undoStack.save(@_snapshot())

  changeSetDidAddChanges: =>
    return if @_destroyed
    if !@_draft
      throw new Error("DraftChangeSet was modified before the draft was prepared.")

    @changes.applyToModel(@_draft)
    @trigger()

  restoreSnapshot: (snapshot) =>
    return unless snapshot
    @_restoring = true
    @changes.add(snapshot.draft)
    if @_composerViewSelectionRestore
      @_composerViewSelectionRestore(snapshot.selection)
    @_restoring = false

  undo: =>
    @restoreSnapshot(@_undoStack.saveAndUndo(@_snapshot()))

  redo: =>
    @restoreSnapshot(@_undoStack.redo())

  _snapshot: =>
    snapshot = {
      selection: @_composerViewSelectionRetrieve?()
      draft: Object.assign({}, @draft())
    }
    for {pluginId, value} in snapshot.draft.pluginMetadata
      snapshot.draft["#{MetadataChangePrefix}#{pluginId}"] = value
    delete snapshot.draft.pluginMetadata
    return snapshot


DraftEditingSession.DraftChangeSet = DraftChangeSet

module.exports = DraftEditingSession
