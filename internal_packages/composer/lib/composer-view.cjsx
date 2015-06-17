React = require 'react'
_ = require 'underscore'

{Utils,
 Actions,
 UndoManager,
 DraftStore,
 FileUploadStore,
 FileDownloadStore} = require 'nylas-exports'

{ResizableRegion,
 InjectedComponentSet,
 InjectedComponent,
 RetinaImg} = require 'nylas-component-kit'

FileUpload = require './file-upload'
ImageFileUpload = require './image-file-upload'
ContenteditableComponent = require './contenteditable-component'
ParticipantsTextField = require './participants-text-field'

# The ComposerView is a unique React component because it (currently) is a
# singleton. Normally, the React way to do things would be to re-render the
# Composer with new props.
class ComposerView extends React.Component
  @displayName: 'ComposerView'

  @containerRequired: false

  @propTypes:
    localId: React.PropTypes.string.isRequired

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
      showcc: false
      showbcc: false
      showsubject: false
      showQuotedText: false
      isSending: DraftStore.isSendingDraft(@props.localId)
      uploads: FileUploadStore.uploadsForMessage(@props.localId) ? []

  componentWillMount: =>
    @_prepareForDraft(@props.localId)

  componentDidMount: =>
    @_draftStoreUnlisten = DraftStore.listen @_onSendingStateChanged
    @_uploadUnlisten = FileUploadStore.listen @_onFileUploadStoreChange
    @_keymapUnlisten = atom.commands.add '.composer-outer-wrap', {
      'composer:show-and-focus-bcc': @_showAndFocusBcc
      'composer:show-and-focus-cc': @_showAndFocusCc
      'composer:focus-to': => @focus "textFieldTo"
      'composer:send-message': => @_sendDraft()
      'composer:delete-empty-draft': => @_deleteEmptyDraft()
      "core:undo": @undo
      "core:redo": @redo
    }
    if @props.mode is "fullwindow"
      # Need to delay so the component can be fully painted. Focus doesn't
      # work unless the element is on the page.
      @focus "textFieldTo"

  componentWillUnmount: =>
    @_unmounted = true # rarf
    @_teardownForDraft()
    @_uploadUnlisten() if @_uploadUnlisten
    @_draftStoreUnlisten() if @_draftStoreUnlisten
    @_keymapUnlisten.dispose() if @_keymapUnlisten

  componentDidUpdate: =>
    # We want to use a temporary variable instead of putting this into the
    # state. This is because the selection is a transient property that
    # only needs to be applied once. It's not a long-living property of
    # the state. We could call `setState` here, but this saves us from a
    # re-rendering.
    @_recoveredSelection = null if @_recoveredSelection?

  componentWillReceiveProps: (newProps) =>
    if newProps.localId isnt @props.localId
      # When we're given a new draft localId, we have to stop listening to our
      # current DraftStoreProxy, create a new one and listen to that. The simplest
      # way to do this is to just re-call registerListeners.
      @_teardownForDraft()
      @_prepareForDraft(newProps.localId)

  _prepareForDraft: (localId) =>
    @unlisteners = []
    return unless localId

    # UndoManager must be ready before we call _onDraftChanged for the first time
    @undoManager = new UndoManager
    DraftStore.sessionForLocalId(localId).then(@_setupSession)

  _setupSession: (proxy) =>
    return if @_unmounted
    return unless proxy.draftLocalId is @props.localId
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

  render: =>
    if @props.mode is "inline"
      <div className={@_wrapClasses()}>
        <ResizableRegion handle={ResizableRegion.Handle.Bottom}>
          {@_renderComposer()}
        </ResizableRegion>
      </div>
    else
      <div className={@_wrapClasses()}>
        {@_renderComposer()}
      </div>

  _wrapClasses: =>
    "composer-outer-wrap #{@props.className ? ""}"

  _renderComposer: =>
    <div className="composer-inner-wrap" onDragOver={@_onDragNoop} onDragLeave={@_onDragNoop} onDragEnd={@_onDragNoop} onDrop={@_onDrop}>

      <div className="composer-cover"
           style={display: (if @state.isSending then "block" else "none")}>
      </div>

      <div className="composer-content-wrap">

        <div className="composer-participant-actions">
          <span className="header-action"
                style={display: @state.showcc and 'none' or 'inline'}
                onClick={=> @_showAndFocusCc()}>Cc</span>

          <span className="header-action"
                style={display: @state.showbcc and 'none' or 'inline'}
                onClick={=> @_showAndFocusBcc()}>Bcc</span>

          <span className="header-action"
                style={display: @state.showsubject and 'none' or 'initial'}
                onClick={=> @setState {showsubject: true}}>Subject</span>

          <span className="header-action"
                data-tooltip="Popout composer"
                style={{display: ((@props.mode is "fullwindow") and 'none' or 'initial'), paddingLeft: "1.5em"}}
                onClick={@_popoutComposer}>
            <RetinaImg name="composer-popout.png"
              mode={RetinaImg.Mode.ContentIsMask}
              style={{position: "relative", top: "-2px"}}/>
          </span>

        </div>

        {@_renderFields()}

        <div className="compose-body">
          <ContenteditableComponent ref="contentBody"
                                    html={@state.body}
                                    onChange={@_onChangeBody}
                                    onFilePaste={@_onFilePaste}
                                    style={@_precalcComposerCss}
                                    initialSelectionSnapshot={@_recoveredSelection}
                                    mode={{showQuotedText: @state.showQuotedText}}
                                    onChangeMode={@_onChangeEditableMode}
                                    onRequestScrollTo={@props.onRequestScrollTo}
                                    tabIndex="109" />

          {@_renderFooterRegions()}

        </div>
      </div>

      <div className="composer-action-bar-wrap">
        {@_renderActionsRegion()}
      </div>
    </div>

  _renderFields: =>
    # Note: We need to physically add and remove these elements, not just hide them.
    # If they're hidden, shift-tab between fields breaks.
    fields = []
    fields.push(
      <ParticipantsTextField
        ref="textFieldTo"
        key="to"
        field='to'
        change={@_onChangeParticipants}
        participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
        tabIndex='102'/>
    )

    if @state.showcc
      fields.push(
        <ParticipantsTextField
          ref="textFieldCc"
          key="cc"
          field='cc'
          change={@_onChangeParticipants}
          onEmptied={@_onEmptyCc}
          participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
          tabIndex='103'/>
      )

    if @state.showbcc
      fields.push(
        <ParticipantsTextField
          ref="textFieldBcc"
          key="bcc"
          field='bcc'
          change={@_onChangeParticipants}
          onEmptied={@_onEmptyBcc}
          participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
          tabIndex='104'/>
      )

    if @state.showsubject
      fields.push(
        <div key="subject" className="compose-subject-wrap">
          <input type="text"
                 key="subject"
                 name="subject"
                 tabIndex="108"
                 placeholder="Subject:"
                 disabled={not @state.showsubject}
                 className="compose-field compose-subject"
                 value={@state.subject}
                 onChange={@_onChangeSubject}/>
        </div>
      )

    fields

  _renderFooterRegions: =>
    return <div></div> unless @props.localId

    <div className="composer-footer-region">
      <div className="attachments-area">
        {@_renderNonImageAttachmentsAndUploads()}
        {@_renderImageAttachmentsAndUploads()}
      </div>
      <InjectedComponentSet
        matching={role: "Composer:Footer"}
        exposedProps={draftLocalId:@props.localId, threadId: @props.threadId}/>
    </div>

  _renderNonImageAttachmentsAndUploads: ->
    @_nonImages().map (fileOrUpload) =>
      if fileOrUpload.object is "file"
        @_attachmentComponent(fileOrUpload)
      else
        <FileUpload key={fileOrUpload.uploadId}
                    uploadData={fileOrUpload} />

  _renderImageAttachmentsAndUploads: ->
    @_images().map (fileOrUpload) =>
      if fileOrUpload.object is "file"
        @_attachmentComponent(fileOrUpload, "Attachment:Image")
      else
        <ImageFileUpload key={fileOrUpload.uploadId}
                         uploadData={fileOrUpload} />

  _attachmentComponent: (file, role="Attachment") =>
    targetPath = FileUploadStore.linkedUpload(file)?.filePath
    if not targetPath
      targetPath = FileDownloadStore.pathForFile(file)

    props =
      file: file
      removable: true
      targetPath: targetPath
      messageLocalId: @props.localId

    if role is "Attachment" then className = "non-image-attachment attachment-file-wrap"
    else className = "image-attachment-file-wrap"

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
      sortOrder = uploadData.startedUploadingAt + (1 / +uploadData.uploadId)

    return sortOrder

  _images: ->
    _.sortBy _.filter(@_uploadsAndFiles(), Utils.looksLikeImage), @_fileSort

  _nonImages: ->
    _.sortBy _.reject(@_uploadsAndFiles(), Utils.looksLikeImage), @_fileSort

  _uploadsAndFiles: ->
    _.compact(@state.uploads.concat(@state.files))

  _onFileUploadStoreChange: =>
    @setState uploads: FileUploadStore.uploadsForMessage(@props.localId)

  _renderActionsRegion: =>
    return <div></div> unless @props.localId

    <InjectedComponentSet className="composer-action-bar-content"
                      matching={role: "Composer:ActionButton"}
                      exposedProps={draftLocalId:@props.localId, threadId: @props.threadId}>

      <button className="btn btn-toolbar btn-trash" style={order: 100}
              data-tooltip="Delete draft"
              onClick={@_destroyDraft}><RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <button className="btn btn-toolbar btn-attach" style={order: 50}
              data-tooltip="Attach file"
              onClick={@_attachFile}><RetinaImg name="toolbar-attach.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <div style={order: 0, flex: 1} />

      <button className="btn btn-toolbar btn-emphasis btn-send" style={order: -100}
              data-tooltip="Send message"
              ref="sendButton"
              onClick={@_sendDraft}><RetinaImg name="toolbar-send.png" mode={RetinaImg.Mode.ContentIsMask} /> Send</button>

    </InjectedComponentSet>

  # Focus the composer view. Chooses the appropriate field to start
  # focused depending on the draft type, or you can pass a field as
  # the first parameter.
  focus: (field = null) =>
    if not @_proxy
      @_focusRequested = true
      return

    if @isForwardedMessage()
      field ?= "textFieldTo"
    else
      field ?= "contentBody"

    @refs[field]?.focus?()

  isForwardedMessage: =>
    return false if not @_proxy
    draft = @_proxy.draft()
    Utils.isForwardedMessage(draft)

  _onDraftChanged: =>
    return unless @_proxy
    draft = @_proxy.draft()

    if not @_initialHistorySave
      @_saveToHistory()
      @_initialHistorySave = true

    if @_focusRequested
      @_focusRequested = false
      @focus()

    state =
      to: draft.to
      cc: draft.cc
      bcc: draft.bcc
      files: draft.files
      subject: draft.subject
      body: draft.body

    if !@state.populated
      _.extend state,
        showcc: not _.isEmpty(draft.cc)
        showbcc: not _.isEmpty(draft.bcc)
        showsubject: @_shouldShowSubject()
        showQuotedText: @isForwardedMessage()
        populated: true

    @setState(state)

  _shouldShowSubject: =>
    return false unless @_proxy
    draft = @_proxy.draft()
    if _.isEmpty(draft.subject ? "") then return true
    else if @isForwardedMessage() then return true
    else return false

  _onDragNoop: (e) =>
    e.preventDefault()

  _onDrop: (e) =>
    e.preventDefault()
    for file in e.dataTransfer.files
      Actions.attachFilePath({path: file.path, messageLocalId: @props.localId})
    true

  _onFilePaste: (path) =>
    Actions.attachFilePath({path: path, messageLocalId: @props.localId})

  _onChangeParticipants: (changes={}) => @_addToProxy(changes)
  _onChangeSubject: (event) => @_addToProxy(subject: event.target.value)

  _onChangeBody: (event) =>
    return unless @_proxy
    if @_getSelections().currentSelection?.atEndOfContent
      @props.onRequestScrollTo?(messageId: @_proxy.draft().id, location: "bottom")
    @_addToProxy(body: event.target.value)

  _onChangeEditableMode: ({showQuotedText}) =>
    @setState showQuotedText: showQuotedText

  _addToProxy: (changes={}, source={}) =>
    return unless @_proxy

    selections = @_getSelections()

    oldDraft = @_proxy.draft()
    return if _.all changes, (change, key) -> _.isEqual(change, oldDraft[key])
    @_proxy.changes.add(changes)

    @_saveToHistory(selections) unless source.fromUndoManager

  _popoutComposer: =>
    Actions.composePopoutDraft @props.localId

  _sendDraft: (options = {}) =>
    return unless @_proxy

    return if @state.isSending

    draft = @_proxy.draft()
    remote = require('remote')
    dialog = remote.require('dialog')

    if [].concat(draft.to, draft.cc, draft.bcc).length is 0
      dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Edit Message'],
        message: 'Cannot Send',
        detail: 'You need to provide one or more recipients before sending the message.'
      })
      return

    body = draft.body.toLowerCase().trim()
    forwarded = Utils.isForwardedMessage(draft)
    quotedTextIndex = Utils.quotedTextIndex(body)
    hasAttachment = (draft.files ? []).length > 0

    # Note: In a completely empty reply, quotedTextIndex is 8
    # due to opening elements.
    bodyIsEmpty = body.length is 0 or 0 <= quotedTextIndex <= 8

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
        buttons: ['Cancel', 'Send Anyway'],
        message: 'Are you sure?',
        detail: "Send #{warnings.join(' and ')}?"
      }, (response) =>
        if response is 1 # button array index 1
          @_sendDraft({force: true})
      return

    # There can be a delay between when the send request gets initiated
    # by a user and when the draft is prepared on on the TaskQueue, which
    # is how we detect that the draft is sending.
    @setState isSending: true

    Actions.sendDraft(@props.localId)

  _mentionsAttachment: (body) =>
    body = body.toLowerCase().trim()
    attachIndex = body.indexOf("attach")
    if attachIndex >= 0
      quotedTextIndex = Utils.quotedTextIndex(body)
      if quotedTextIndex >= 0
        return (attachIndex < quotedTextIndex)
      else return true
    else return false

  _destroyDraft: =>
    Actions.destroyDraft(@props.localId)

  _attachFile: =>
    Actions.attachFile({messageLocalId: @props.localId})

  _showAndFocusBcc: =>
    @setState {showbcc: true}
    @focus "textFieldBcc"

  _showAndFocusCc: =>
    @setState {showcc: true}
    @focus "textFieldCc"

  _onSendingStateChanged: =>
    @setState isSending: DraftStore.isSendingDraft(@props.localId)

  _onEmptyCc: =>
    @setState showcc: false
    @focus "textFieldTo"

  _onEmptyBcc: =>
    @setState showbcc: false
    if @state.showcc
      @focus "textFieldCc"
    else
      @focus "textFieldTo"

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
    currentSelection: @refs.contentBody?.getCurrentSelection?()
    previousSelection: @refs.contentBody?.getPreviousSelection?()

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

  _deleteEmptyDraft: =>
    return unless @_proxy
    if @_proxy.draft().pristine then Actions.destroyDraft(@props.localId)


module.exports = ComposerView
