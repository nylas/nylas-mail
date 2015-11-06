_ = require 'underscore'
React = require 'react'

{File,
 Utils,
 Actions,
 DraftStore,
 UndoManager,
 ContactStore,
 AccountStore,
 FileUploadStore,
 QuotedHTMLParser,
 FileDownloadStore} = require 'nylas-exports'

{DropZone,
 RetinaImg,
 ScrollRegion,
 Contenteditable,
 InjectedComponent,
 KeyCommandsRegion,
 FocusTrackingRegion,
 InjectedComponentSet} = require 'nylas-component-kit'

FileUpload = require './file-upload'
ImageFileUpload = require './image-file-upload'

ExpandedParticipants = require './expanded-participants'
CollapsedParticipants = require './collapsed-participants'

Fields = require './fields'

# The ComposerView is a unique React component because it (currently) is a
# singleton. Normally, the React way to do things would be to re-render the
# Composer with new props.
class ComposerView extends React.Component
  @displayName: 'ComposerView'

  @containerRequired: false

  @propTypes:
    draftClientId: React.PropTypes.string.isRequired

    # Either "inline" or "fullwindow"
    mode: React.PropTypes.string

    # If this composer is part of an existing thread (like inline
    # composers) the threadId will be handed down
    threadId: React.PropTypes.string

    # Sometimes when changes in the composer happens it's desirable to
    # have the parent scroll to a certain location. A parent component can
    # pass a callback that gets called when this composer wants to be
    # scrolled to.
    onRequestScrollTo: React.PropTypes.func

  constructor: (@props) ->
    @state =
      populated: false
      to: []
      cc: []
      bcc: []
      body: ""
      files: []
      subject: ""
      focusedField: Fields.To # Gets updated in @_initiallyFocusedField
      enabledFields: [] # Gets updated in @_initiallyEnabledFields
      showQuotedText: false
      uploads: FileUploadStore.uploadsForMessage(@props.draftClientId) ? []

  componentWillMount: =>
    @_prepareForDraft(@props.draftClientId)

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidMount: =>
    @_usubs = []
    @_usubs.push FileUploadStore.listen @_onFileUploadStoreChange
    @_usubs.push AccountStore.listen @_onAccountStoreChanged
    @_applyFocusedField()

  componentWillUnmount: =>
    @_unmounted = true # rarf
    @_teardownForDraft()
    @_deleteDraftIfEmpty()
    usub() for usub in @_usubs

  componentDidUpdate: =>
    # We want to use a temporary variable instead of putting this into the
    # state. This is because the selection is a transient property that
    # only needs to be applied once. It's not a long-living property of
    # the state. We could call `setState` here, but this saves us from a
    # re-rendering.
    @_recoveredSelection = null if @_recoveredSelection?

    @_applyFocusedField()

  _keymapHandlers: ->
    'composer:send-message': => @_sendDraft()
    'composer:delete-empty-draft': => @_deleteDraftIfEmpty()
    'composer:show-and-focus-bcc': =>
      @_onChangeEnabledFields(show: [Fields.Bcc], focus: Fields.Bcc)
    'composer:show-and-focus-cc': =>
      @_onChangeEnabledFields(show: [Fields.Cc], focus: Fields.Cc)
    'composer:focus-to': =>
      @_onChangeEnabledFields(show: [Fields.To], focus: Fields.To)
    "composer:show-and-focus-from": => # TODO
    "composer:undo": @undo
    "composer:redo": @redo

  _applyFocusedField: ->
    if @state.focusedField
      return unless @refs[@state.focusedField]
      if @refs[@state.focusedField].focus
        @refs[@state.focusedField].focus()
      else
        React.findDOMNode(@refs[@state.focusedField]).focus()

  componentWillReceiveProps: (newProps) =>
    @_ignoreNextTrigger = false
    if newProps.draftClientId isnt @props.draftClientId
      # When we're given a new draft draftClientId, we have to stop listening to our
      # current DraftStoreProxy, create a new one and listen to that. The simplest
      # way to do this is to just re-call registerListeners.
      @_teardownForDraft()
      @_prepareForDraft(newProps.draftClientId)

  _prepareForDraft: (draftClientId) =>
    @unlisteners = []
    return unless draftClientId

    # UndoManager must be ready before we call _onDraftChanged for the first time
    @undoManager = new UndoManager
    DraftStore.sessionForClientId(draftClientId).then(@_setupSession)

  _setupSession: (proxy) =>
    return if @_unmounted
    return unless proxy.draftClientId is @props.draftClientId
    @_proxy = proxy
    @_preloadImages(@_proxy.draft()?.files)
    @unlisteners.push @_proxy.listen(@_onDraftChanged)
    @_onDraftChanged()

  _preloadImages: (files=[]) ->
    files.forEach (file) ->
      uploadData = FileUploadStore.linkedUpload(file)
      if not uploadData? and Utils.looksLikeImage(file)
        Actions.fetchFile(file)

  _teardownForDraft: =>
    unlisten() for unlisten in @unlisteners
    if @_proxy
      @_proxy.changes.commit()

  render: ->
    <KeyCommandsRegion localHandlers={@_keymapHandlers()} >
      {@_renderComposerWrap()}
    </KeyCommandsRegion>

  _renderComposerWrap: =>
    if @props.mode is "inline"
      <FocusTrackingRegion className={@_wrapClasses()}
                           ref="composerWrap"
                           tabIndex="-1">
        {@_renderComposer()}
      </FocusTrackingRegion>
    else
      <div className={@_wrapClasses()} ref="composerWrap">
        {@_renderComposer()}
      </div>

  _wrapClasses: =>
    "message-item-white-wrap composer-outer-wrap #{@props.className ? ""}"

  _renderComposer: =>
    <DropZone className="composer-inner-wrap"
              shouldAcceptDrop={@_shouldAcceptDrop}
              onDragStateChange={ ({isDropping}) => @setState({isDropping}) }
              onDrop={@_onDrop}>
      <div className="composer-drop-cover" style={display: if @state.isDropping then 'block' else 'none'}>
        <div className="centered">
          <RetinaImg name="composer-drop-to-attach.png" mode={RetinaImg.Mode.ContentIsMask}/>
          Drop to attach
        </div>
      </div>

      <div className="composer-content-wrap" onKeyDown={@_onKeyDown}>
        {@_renderScrollRegion()}

      </div>
      <div className="composer-action-bar-wrap">
        {@_renderActionsRegion()}
      </div>
    </DropZone>

  _renderScrollRegion: ->
    if @props.mode is "inline"
      @_renderContent()
    else
      <ScrollRegion className="compose-body-scroll" ref="scrollregion">
        {@_renderContent()}
      </ScrollRegion>

  _renderContent: ->
    <div className="composer-centered">
      {if @state.focusedField in Fields.ParticipantFields
        <ExpandedParticipants
          to={@state.to} cc={@state.cc} bcc={@state.bcc}
          from={@state.from}
          ref="expandedParticipants"
          mode={@props.mode}
          focusedField={@state.focusedField}
          enabledFields={@state.enabledFields}
          onPopoutComposer={@_onPopoutComposer}
          onChangeParticipants={@_onChangeParticipants}
          onChangeEnabledFields={@_onChangeEnabledFields} />
      else
        <CollapsedParticipants
          to={@state.to} cc={@state.cc} bcc={@state.bcc}
          onClick={@_focusParticipantField} />
      }

      {@_renderSubject()}

      <div className="compose-body" ref="composeBody" onClick={@_onClickComposeBody}>
        {@_renderBody()}
        {@_renderFooterRegions()}
      </div>
    </div>

  _onPopoutComposer: =>
    Actions.composePopoutDraft @props.draftClientId

  _onKeyDown: (event) =>
    if event.key is "Tab"
      @_onTabDown(event)
    return

  _onTabDown: (event) =>
    event.preventDefault()
    enabledFields = _.filter @state.enabledFields, (field) ->
      Fields.Order[field] >= 0
    enabledFields = _.sortBy enabledFields, (field) ->
      Fields.Order[field]
    i = enabledFields.indexOf @state.focusedField
    dir = if event.shiftKey then -1 else 1
    newI = Math.min(Math.max(i + dir, 0), enabledFields.length - 1)
    @setState focusedField: enabledFields[newI]
    event.stopPropagation()

  _onChangeParticipantField: (focusedField) =>
    @setState {focusedField}
    @_lastFocusedParticipantField = focusedField

  _focusParticipantField: =>
    @setState focusedField: @_lastFocusedParticipantField ? Fields.To

  _onChangeEnabledFields: ({show, hide, focus}={}) =>
    show = show ? []; hide = hide ? []
    newFields = _.difference(@state.enabledFields.concat(show), hide)
    @setState
      enabledFields: newFields
      focusedField: (focus ? @state.focusedField)

  _renderSubject: ->
    if Fields.Subject in @state.enabledFields
      <div key="subject-wrap" className="compose-subject-wrap">
        <input type="text"
               name="subject"
               ref={Fields.Subject}
               placeholder="Subject"
               value={@state.subject}
               onFocus={ => @setState focusedField: Fields.Subject}
               onChange={@_onChangeSubject}/>
      </div>

  _renderBody: =>
    <span ref="composerBodyWrap">
      {@_renderBodyContenteditable()}
      {@_renderQuotedTextControl()}
      {@_renderAttachments()}
    </span>

  _renderBodyContenteditable: ->
    <Contenteditable
      ref={Fields.Body}
      value={@_removeQuotedText(@state.body)}
      onFocus={ => @setState focusedField: Fields.Body}
      onChange={@_onChangeBody}
      onScrollTo={@props.onRequestScrollTo}
      onFilePaste={@_onFilePaste}
      onScrollToBottom={@_onScrollToBottom()}
      lifecycleCallbacks={@_contenteditableLifecycleCallbacks()}
      getComposerBoundingRect={@_getComposerBoundingRect}
      initialSelectionSnapshot={@_recoveredSelection} />

  _contenteditableLifecycleCallbacks: ->
    componentDidUpdate: (editableNode) =>
      for extension in DraftStore.extensions()
        extension.onComponentDidUpdate?(editableNode)

    onInput: (editableNode, event) =>
      for extension in DraftStore.extensions()
        extension.onInput?(editableNode, event)

    onTabDown: (editableNode, event, range) =>
      for extension in DraftStore.extensions()
        extension.onTabDown?(editableNode, range, event)

    onSubstitutionPerformed: (editableNode) =>
      for extension in DraftStore.extensions()
        extension.onSubstitutionPerformed?(editableNode)

    onLearnSpelling: (editableNode, text) =>
      for extension in DraftStore.extensions()
        extension.onLearnSpelling?(editableNode, text)

    onMouseUp: (editableNode, event, range) =>
      return unless range
      try
        for extension in DraftStore.extensions()
          extension.onMouseUp?(editableNode, range, event)
      catch e
        console.error('DraftStore extension raised an error: '+e.toString())

  # The contenteditable decides when to request a scroll based on the
  # position of the cursor and its relative distance to this composer
  # component. We provide it our boundingClientRect so it can calculate
  # this value.
  _getComposerBoundingRect: =>
    React.findDOMNode(@refs.composerWrap).getBoundingClientRect()

  _onScrollToBottom: ->
    if @props.onRequestScrollTo
      return =>
        @props.onRequestScrollTo
          clientId: @_proxy.draft().clientId
          position: ScrollRegion.ScrollPosition.Bottom
    else return null

  _removeQuotedText: (html) =>
    if @state.showQuotedText then return html
    else return QuotedHTMLParser.removeQuotedHTML(html)

  _showQuotedText: (html) =>
    if @state.showQuotedText then return html
    else return QuotedHTMLParser.appendQuotedHTML(html, @state.body)

  _renderQuotedTextControl: ->
    if QuotedHTMLParser.hasQuotedHTML(@state.body)
      text = if @state.showQuotedText then "Hide" else "Show"
      <a className="quoted-text-control" onClick={@_onToggleQuotedText}>
        <span className="dots">&bull;&bull;&bull;</span>{text} previous
      </a>
    else return []

  _onToggleQuotedText: =>
    @setState showQuotedText: not @state.showQuotedText

  _renderFooterRegions: =>
    return <div></div> unless @props.draftClientId

    <div className="composer-footer-region">
      <InjectedComponentSet
        matching={role: "Composer:Footer"}
        exposedProps={draftClientId:@props.draftClientId, threadId: @props.threadId}/>
    </div>

  _renderAttachments: ->
    renderSubset = (arr, attachmentRole, UploadComponent) =>
      arr.map (fileOrUpload) =>
        if fileOrUpload instanceof File
          @_attachmentComponent(fileOrUpload, attachmentRole)
        else
          <UploadComponent key={fileOrUpload.uploadTaskId} uploadData={fileOrUpload} />

    <div className="attachments-area">
      {renderSubset(@_nonImages(), 'Attachment', FileUpload)}
      {renderSubset(@_images(), 'Attachment:Image', ImageFileUpload)}
    </div>

  _attachmentComponent: (file, role="Attachment") =>
    targetPath = FileUploadStore.linkedUpload(file)?.filePath
    if not targetPath
      targetPath = FileDownloadStore.pathForFile(file)

    props =
      file: file
      removable: true
      targetPath: targetPath
      messageClientId: @props.draftClientId

    if role is "Attachment"
      className = "file-wrap"
    else
      className = "file-wrap file-image-wrap"

    <InjectedComponent key={file.id}
                       matching={role: role}
                       className={className}
                       exposedProps={props} />

  _fileSort: (fileOrUpload) ->
    if fileOrUpload.object is "file"
      # There will only be an entry in the `linkedUpload` if the file had
      # finished uploading in this session. We may well have files that
      # already existed on a draft that don't have any uploadData
      # associated with them.
      uploadData = FileUploadStore.linkedUpload(fileOrUpload)
    else
      uploadData = fileOrUpload

    if not uploadData
      sortOrder = 0
    else
      sortOrder = (uploadData.startDate / 1) + 1.0 / (uploadData.startId/1)

    return sortOrder

  _images: ->
    _.sortBy _.filter(@_uploadsAndFiles(), Utils.looksLikeImage), @_fileSort

  _nonImages: ->
    _.sortBy _.reject(@_uploadsAndFiles(), Utils.looksLikeImage), @_fileSort

  _uploadsAndFiles: ->
    # When uploads finish, they stay attached to the object at 100%
    # completion. Eventually the DB trigger will make its way to a window
    # and the files will appear on the draft.
    #
    # In this case we want to show the file instead of the upload
    uploads = _.filter @state.uploads, (upload) =>
      for file in @state.files
        linkedUpload = FileUploadStore.linkedUpload(file)
        return false if linkedUpload and linkedUpload.uploadTaskId is upload.uploadTaskId
      return true

    _.compact(uploads.concat(@state.files))

  _onFileUploadStoreChange: =>
    @setState uploads: FileUploadStore.uploadsForMessage(@props.draftClientId)

  _renderActionsRegion: =>
    return <div></div> unless @props.draftClientId

    <InjectedComponentSet className="composer-action-bar-content"
                      matching={role: "Composer:ActionButton"}
                      exposedProps={draftClientId:@props.draftClientId, threadId: @props.threadId}>

      <button className="btn btn-toolbar btn-trash" style={order: 100}
              title="Delete draft"
              onClick={@_destroyDraft}><RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <button className="btn btn-toolbar btn-attach" style={order: 50}
              title="Attach file"
              onClick={@_attachFile}><RetinaImg name="icon-composer-attachment.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <div style={order: 0, flex: 1} />

      <button className="btn btn-toolbar btn-emphasis btn-text btn-send" style={order: -100}
              ref="sendButton"
              onClick={@_sendDraft}><RetinaImg name="icon-composer-send.png" mode={RetinaImg.Mode.ContentIsMask} /><span className="text">Send</span></button>

    </InjectedComponentSet>

  isForwardedMessage: =>
    return false if not @_proxy
    draft = @_proxy.draft()
    Utils.isForwardedMessage(draft)

  # This lets us click outside of the `contenteditable`'s `contentBody`
  # and simulate what happens when you click beneath the text *in* the
  # contentEditable.
  _onClickComposeBody: (event) =>
    @refs[Fields.Body].selectEnd()

  _onDraftChanged: =>
    return if @_ignoreNextTrigger
    return unless @_proxy
    draft = @_proxy.draft()

    if not @_initialHistorySave
      @_saveToHistory()
      @_initialHistorySave = true

    state =
      to: draft.to
      cc: draft.cc
      bcc: draft.bcc
      from: draft.from
      body: draft.body
      files: draft.files
      subject: draft.subject

    if !@state.populated
      _.extend state,
        populated: true
        focusedField: @_initiallyFocusedField(draft)
        enabledFields: @_initiallyEnabledFields(draft)
        showQuotedText: @isForwardedMessage()

    state = @_verifyEnabledFields(draft, state)

    @setState(state)

  _initiallyFocusedField: (draft) ->
    return Fields.To if draft.to.length is 0
    return Fields.Subject if (draft.subject ? "").trim().length is 0
    return Fields.Body

  _verifyEnabledFields: (draft, state) ->
    enabledFields = @state.enabledFields.concat(state.enabledFields)
    updated = false
    if draft.cc.length > 0
      updated = true
      enabledFields.push(Fields.Cc)

    if draft.bcc.length > 0
      updated = true
      enabledFields.push(Fields.Bcc)

    if updated
      state.enabledFields = _.uniq(enabledFields)

    return state

  _initiallyEnabledFields: (draft) ->
    enabledFields = [Fields.To]
    enabledFields.push Fields.Cc if not _.isEmpty(draft.cc)
    enabledFields.push Fields.Bcc if not _.isEmpty(draft.bcc)
    enabledFields.push Fields.From if @_shouldShowFromField(draft)
    enabledFields.push Fields.Subject if @_shouldEnableSubject()
    enabledFields.push Fields.Body
    return enabledFields

  # When the account store changes, the From field may or may not still
  # be in scope. We need to make sure to update our enabled fields.
  _onAccountStoreChanged: =>
    if @_shouldShowFromField(@_proxy?.draft())
      enabledFields = @state.enabledFields.concat [Fields.From]
    else
      enabledFields = _.without(@state.enabledFields, Fields.From)
    @setState {enabledFields}

  _shouldShowFromField: (draft) ->
    return false unless draft
    return AccountStore.items().length > 1 and
           not draft.replyToMessageId and
           draft.files.length is 0

  _shouldEnableSubject: =>
    return false unless @_proxy
    draft = @_proxy.draft()
    if _.isEmpty(draft.subject ? "") then return true
    else if @isForwardedMessage() then return true
    else if draft.replyToMessageId then return false
    else return true

  _shouldAcceptDrop: (event) =>
    # Ensure that you can't pick up a file and drop it on the same draft
    existingFilePaths = @state.files.map (f) ->
      FileUploadStore.linkedUpload(f)?.filePath

    nonNativeFilePath = @_nonNativeFilePathForDrop(event)
    if nonNativeFilePath and nonNativeFilePath in existingFilePaths
      return false

    hasNativeFile = event.dataTransfer.files.length > 0
    hasNonNativeFilePath = nonNativeFilePath isnt null

    return hasNativeFile or hasNonNativeFilePath

  _nonNativeFilePathForDrop: (event) =>
    if "text/nylas-file-url" in event.dataTransfer.types
      downloadURL = event.dataTransfer.getData("text/nylas-file-url")
      downloadFilePath = downloadURL.split('file://')[1]
      if downloadFilePath
        return downloadFilePath

    # Accept drops of images from within the app
    if "text/uri-list" in event.dataTransfer.types
      uri = event.dataTransfer.getData('text/uri-list')
      if uri.indexOf('file://') is 0
        uri = decodeURI(uri.split('file://')[1])
        return uri

    return null

  _onDrop: (e) =>
    # Accept drops of real files from other applications
    for file in e.dataTransfer.files
      Actions.attachFilePath({path: file.path, messageClientId: @props.draftClientId})

    # Accept drops from attachment components / images within the app
    if (uri = @_nonNativeFilePathForDrop(e))
      Actions.attachFilePath({path: uri, messageClientId: @props.draftClientId})

  _onFilePaste: (path) =>
    Actions.attachFilePath({path: path, messageClientId: @props.draftClientId})

  _onChangeParticipants: (changes={}) =>
    @_addToProxy(changes)

  _onChangeSubject: (event) =>
    @_addToProxy(subject: event.target.value)

  _onChangeBody: (event) =>
    return unless @_proxy

    newBody = @_showQuotedText(event.target.value)

    # The body changes extremely frequently (on every key stroke). To keep
    # performance up, we don't want to trigger every single key stroke
    # since that will cause an entire composer re-render. We, however,
    # never want to lose any data, so we still add data to the proxy on
    # every keystroke.
    #
    # We want to use debounce instead of throttle because we don't want ot
    # trigger janky re-renders mid quick-type. Let's just do it at the end
    # when you're done typing and about to move onto something else.
    @_addToProxy({body: newBody}, {fromBodyChange: true})
    @_throttledTrigger ?= _.debounce =>
      @_ignoreNextTrigger = false
      @_proxy.trigger()
    , 100

    @_throttledTrigger()
    return

  _addToProxy: (changes={}, source={}) =>
    return unless @_proxy

    selections = @_getSelections()

    oldDraft = @_proxy.draft()
    return if _.all changes, (change, key) -> _.isEqual(change, oldDraft[key])

    # Other extensions might want to hear about changes immediately. We
    # only need to prevent this view from re-rendering until we're done
    # throttling body changes.
    if source.fromBodyChange then @_ignoreNextTrigger = true

    @_proxy.changes.add(changes)

    @_saveToHistory(selections) unless source.fromUndoManager

  _sendDraft: (options = {}) =>
    return unless @_proxy

    # We need to check the `DraftStore` because the `DraftStore` is
    # immediately and synchronously updated as soon as this function
    # fires. Since `setState` is asynchronous, if we used that as our only
    # check, then we might get a false reading.
    return if DraftStore.isSendingDraft(@props.draftClientId)

    draft = @_proxy.draft()
    remote = require('remote')
    dialog = remote.require('dialog')

    allRecipients = [].concat(draft.to, draft.cc, draft.bcc)
    for contact in allRecipients
      if not ContactStore.isValidContact(contact)
        dealbreaker = "#{contact.email} is not a valid email address - please remove or edit it before sending."
    if allRecipients.length is 0
      dealbreaker = 'You need to provide one or more recipients before sending the message.'

    if dealbreaker
      dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Edit Message'],
        message: 'Cannot Send',
        detail: dealbreaker
      })
      return

    bodyIsEmpty = draft.body is @_proxy.draftPristineBody()
    forwarded = Utils.isForwardedMessage(draft)
    hasAttachment = (draft.files ? []).length > 0

    warnings = []

    if draft.subject.length is 0
      warnings.push('without a subject line')

    if @_mentionsAttachment(draft.body) and not hasAttachment
      warnings.push('without an attachment')

    if bodyIsEmpty and not forwarded and not hasAttachment
      warnings.push('without a body')

    # Check third party warnings added via DraftStore extensions
    for extension in DraftStore.extensions()
      continue unless extension.warningsForSending
      warnings = warnings.concat(extension.warningsForSending(draft))

    if warnings.length > 0 and not options.force
      dialog.showMessageBox remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Send Anyway', 'Cancel'],
        message: 'Are you sure?',
        detail: "Send #{warnings.join(' and ')}?"
      }, (response) =>
        if response is 0 # response is button array index
          @_sendDraft({force: true})
      return

    Actions.sendDraft(@props.draftClientId)

  _mentionsAttachment: (body) =>
    body = QuotedHTMLParser.removeQuotedHTML(body.toLowerCase().trim())
    return body.indexOf("attach") >= 0

  _destroyDraft: =>
    Actions.destroyDraft(@props.draftClientId)

  _attachFile: =>
    Actions.attachFile({messageClientId: @props.draftClientId})

  undo: (event) =>
    event.preventDefault()
    event.stopPropagation()
    historyItem = @undoManager.undo() ? {}
    return unless historyItem.state?

    @_recoveredSelection = historyItem.currentSelection
    @_addToProxy historyItem.state, fromUndoManager: true
    @_recoveredSelection = null

  redo: (event) =>
    event.preventDefault()
    event.stopPropagation()
    historyItem = @undoManager.redo() ? {}
    return unless historyItem.state?

    @_recoveredSelection = historyItem.currentSelection
    @_addToProxy historyItem.state, fromUndoManager: true
    @_recoveredSelection = null

  _getSelections: =>
    currentSelection: @refs[Fields.Body]?.getCurrentSelection?()
    previousSelection: @refs[Fields.Body]?.getPreviousSelection?()

  _saveToHistory: (selections) =>
    return unless @_proxy
    selections ?= @_getSelections()

    newDraft = @_proxy.draft()

    historyItem =
      previousSelection: selections.previousSelection
      currentSelection: selections.currentSelection
      state:
        body: _.clone newDraft.body
        subject: _.clone newDraft.subject
        to: _.clone newDraft.to
        cc: _.clone newDraft.cc
        bcc: _.clone newDraft.bcc

    lastState = @undoManager.current()
    if lastState?
      lastState.currentSelection = historyItem.previousSelection

    @undoManager.saveToHistory(historyItem)

  _deleteDraftIfEmpty: =>
    return unless @_proxy
    if @_proxy.draft().pristine then Actions.destroyDraft(@props.draftClientId)

module.exports = ComposerView
