React = require 'react'
_ = require 'underscore'

{Utils,
 File,
 Actions,
 DraftStore,
 ContactStore,
 AccountStore,
 UndoManager,
 FileUploadStore,
 QuotedHTMLParser,
 FileDownloadStore} = require 'nylas-exports'

{ResizableRegion,
 InjectedComponentSet,
 InjectedComponent,
 FocusTrackingRegion,
 ScrollRegion,
 ButtonDropdown,
 DropZone,
 Menu,
 RetinaImg} = require 'nylas-component-kit'

FileUpload = require './file-upload'
ImageFileUpload = require './image-file-upload'
ContenteditableComponent = require './contenteditable-component'
ParticipantsTextField = require './participants-text-field'
AccountContactField = require './account-contact-field'

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
      showcc: false
      showbcc: false
      showsubject: false
      showQuotedText: false
      uploads: FileUploadStore.uploadsForMessage(@props.draftClientId) ? []

  componentWillMount: =>
    @_prepareForDraft(@props.draftClientId)

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidMount: =>
    @_uploadUnlisten = FileUploadStore.listen @_onFileUploadStoreChange
    @_keymapUnlisten = atom.commands.add '.composer-outer-wrap', {
      'composer:show-and-focus-bcc': @_showAndFocusBcc
      'composer:show-and-focus-cc': @_showAndFocusCc
      'composer:focus-to': => @focus "textFieldTo"
      'composer:send-message': => @_sendDraft()
      'composer:delete-empty-draft': => @_deleteDraftIfEmpty()
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
    @_deleteDraftIfEmpty()
    @_uploadUnlisten() if @_uploadUnlisten
    @_keymapUnlisten.dispose() if @_keymapUnlisten

  componentDidUpdate: =>
    # We want to use a temporary variable instead of putting this into the
    # state. This is because the selection is a transient property that
    # only needs to be applied once. It's not a long-living property of
    # the state. We could call `setState` here, but this saves us from a
    # re-rendering.
    @_recoveredSelection = null if @_recoveredSelection?

    # We often can't focus until the component state has changed
    # (so the desired field exists or we have a draft)
    if @_focusOnUpdate and @_proxy
      @focus(@_focusOnUpdate.field)
      @_focusOnUpdate = false

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

  render: =>
    if @props.mode is "inline"
      <FocusTrackingRegion className={@_wrapClasses()} onFocus={@focus} tabIndex="-1">
        <ResizableRegion handle={ResizableRegion.Handle.Bottom}>
          {@_renderComposer()}
        </ResizableRegion>
      </FocusTrackingRegion>
    else
      <div className={@_wrapClasses()}>
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

      <div className="composer-content-wrap">
        {@_renderBodyScrollbar()}

        <div className="composer-centered">
          {@_renderFields()}

          <div className="compose-body" ref="composeBody" onClick={@_onClickComposeBody}>
            {@_renderBody()}
            {@_renderFooterRegions()}
          </div>
        </div>

      </div>
      <div className="composer-action-bar-wrap">
        {@_renderActionsRegion()}
      </div>
    </DropZone>

  _renderFields: =>
    # Note: We need to physically add and remove these elements, not just hide them.
    # If they're hidden, shift-tab between fields breaks.
    fields = []
    fields.push(
      <div key="to">
        <div className="composer-participant-actions">
          <span className="header-action"
                style={display: @state.showcc and 'none' or 'inline'}
                onClick={@_showAndFocusCc}>Cc</span>

          <span className="header-action"
                style={display: @state.showbcc and 'none' or 'inline'}
                onClick={@_showAndFocusBcc}>Bcc</span>

          <span className="header-action"
                style={display: @state.showsubject and 'none' or 'initial'}
                onClick={@_showAndFocusSubject}>Subject</span>

          <span className="header-action"
                data-tooltip="Popout composer"
                style={{display: ((@props.mode is "fullwindow") and 'none' or 'initial'), paddingLeft: "1.5em"}}
                onClick={@_popoutComposer}>
            <RetinaImg name="composer-popout.png"
              mode={RetinaImg.Mode.ContentIsMask}
              style={{position: "relative", top: "-2px"}}/>
          </span>
        </div>
        <ParticipantsTextField
          ref="textFieldTo"
          field='to'
          change={@_onChangeParticipants}
          className="composer-participant-field"
          participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
          tabIndex='102'/>
      </div>
    )

    if @state.showcc
      fields.push(
        <ParticipantsTextField
          ref="textFieldCc"
          key="cc"
          field='cc'
          change={@_onChangeParticipants}
          onEmptied={@_onEmptyCc}
          className="composer-participant-field"
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
          className="composer-participant-field"
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
                 ref="textFieldSubject"
                 placeholder="Subject"
                 value={@state.subject}
                 onChange={@_onChangeSubject}/>
        </div>
      )

    if @state.showfrom
      fields.push(
        <AccountContactField
          key="from"
          onChange={ (me) => @_onChangeParticipants(from: [me]) }
          value={@state.from?[0]} />
      )

    fields

  _renderBodyScrollbar: =>
    if @props.mode is "inline"
      []
    else
      <ScrollRegion.Scrollbar ref="scrollbar" getScrollRegion={ => @refs.scrollregion } />

  _renderBody: =>
    if @props.mode is "inline"
      <span>
        {@_renderBodyContenteditable()}
        {@_renderAttachments()}
      </span>
    else
      <ScrollRegion className="compose-body-scroll" ref="scrollregion" getScrollbar={ => @refs.scrollbar }>
        {@_renderBodyContenteditable()}
        {@_renderAttachments()}
      </ScrollRegion>

  _renderBodyContenteditable: =>
    onScrollToBottom = null
    if @props.onRequestScrollTo
      onScrollToBottom = =>
        @props.onRequestScrollTo({messageId: @_proxy.draft().id})

    <ContenteditableComponent ref="contentBody"
                              html={@state.body}
                              onChange={@_onChangeBody}
                              onFilePaste={@_onFilePaste}
                              style={@_precalcComposerCss}
                              initialSelectionSnapshot={@_recoveredSelection}
                              mode={{showQuotedText: @state.showQuotedText}}
                              onChangeMode={@_onChangeEditableMode}
                              onScrollTo={@props.onRequestScrollTo}
                              onScrollToBottom={onScrollToBottom}
                              tabIndex="109" />

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
              data-tooltip="Delete draft"
              onClick={@_destroyDraft}><RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <button className="btn btn-toolbar btn-attach" style={order: 50}
              data-tooltip="Attach file"
              onClick={@_attachFile}><RetinaImg name="icon-composer-attachment.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <div style={order: 0, flex: 1} />

      <button className="btn btn-toolbar btn-emphasis btn-text btn-send" style={order: -100}
              data-tooltip="Send message"
              ref="sendButton"
              onClick={@_sendDraft}><RetinaImg name="icon-composer-send.png" mode={RetinaImg.Mode.ContentIsMask} /><span className="text">Send</span></button>

    </InjectedComponentSet>

  # Focus the composer view. Chooses the appropriate field to start
  # focused depending on the draft type, or you can pass a field as
  # the first parameter.
  focus: (field = null) =>
    if not @_proxy
      @_focusOnUpdate = {field}
      return

    defaultField = "contentBody"
    if @isForwardedMessage() # Note: requires _proxy
      defaultField = "textFieldTo"
    field ?= defaultField

    if not @refs[field]
      @_focusOnUpdate = {field}
      return

    if @refs[field].focus
      @refs[field].focus()
    else
      node = React.findDOMNode(@refs[field])
      node.focus?()

  isForwardedMessage: =>
    return false if not @_proxy
    draft = @_proxy.draft()
    Utils.isForwardedMessage(draft)

  # This lets us click outside of the `contenteditable`'s `contentBody`
  # and simulate what happens when you click beneath the text *in* the
  # contentEditable.
  _onClickComposeBody: (event) =>
    @refs.contentBody.selectEnd()

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
      files: draft.files
      subject: draft.subject
      body: draft.body
      showfrom: not draft.replyToMessageId and draft.files.length is 0

    if !@state.populated
      _.extend state,
        showcc: not _.isEmpty(draft.cc)
        showbcc: not _.isEmpty(draft.bcc)
        showsubject: @_shouldShowSubject()
        showQuotedText: @isForwardedMessage()
        populated: true

    # It's possible for another part of the application to manipulate the draft
    # we're displaying. If they've added a CC or BCC, make sure we show those fields.
    # We should never be hiding the field if it's populated.
    state.showcc = true if not _.isEmpty(draft.cc)
    state.showbcc = true if not _.isEmpty(draft.bcc)

    @setState(state)

  _shouldShowSubject: =>
    return false unless @_proxy
    draft = @_proxy.draft()
    if _.isEmpty(draft.subject ? "") then return true
    else if @isForwardedMessage() then return true
    else return false

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

    # The body changes extremely frequently (on every key stroke). To keep
    # performance up, we don't want to trigger every single key stroke
    # since that will cause an entire composer re-render. We, however,
    # never want to lose any data, so we still add data to the proxy on
    # every keystroke.
    #
    # We want to use debounce instead of throttle because we don't want ot
    # trigger janky re-renders mid quick-type. Let's just do it at the end
    # when you're done typing and about to move onto something else.
    @_addToProxy({body: event.target.value}, {fromBodyChange: true})
    @_throttledTrigger ?= _.debounce =>
      @_ignoreNextTrigger = false
      @_proxy.trigger()
    , 100

    @_throttledTrigger()
    return

  _onChangeEditableMode: ({showQuotedText}) =>
    @setState showQuotedText: showQuotedText

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

  _popoutComposer: =>
    Actions.composePopoutDraft @props.draftClientId

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

  _showAndFocusBcc: =>
    @setState {showbcc: true}
    @focus('textFieldBcc')

  _showAndFocusCc: =>
    @setState {showcc: true}
    @focus('textFieldCc')

  _showAndFocusSubject: =>
    @setState {showsubject: true}
    @focus('textFieldSubject')

  _onEmptyCc: =>
    @setState showcc: false
    @focus('textFieldTo')

  _onEmptyBcc: =>
    @setState showbcc: false
    if @state.showcc
      @focus('textFieldCc')
    else
      @focus('textFieldTo')

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

  _deleteDraftIfEmpty: =>
    return unless @_proxy
    if @_proxy.draft().pristine then Actions.destroyDraft(@props.draftClientId)


module.exports = ComposerView
