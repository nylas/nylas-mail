_ = require 'underscore'
React = require 'react'

{File,
 Utils,
 Actions,
 DOMUtils,
 DraftStore,
 UndoManager,
 ContactStore,
 AccountStore,
 FileUploadStore,
 QuotedHTMLTransformer,
 FileDownloadStore,
 FocusedContentStore,
 ExtensionRegistry} = require 'nylas-exports'

{DropZone,
 RetinaImg,
 ScrollRegion,
 InjectedComponent,
 KeyCommandsRegion,
 InjectedComponentSet} = require 'nylas-component-kit'

FileUpload = require './file-upload'
ImageFileUpload = require './image-file-upload'

ComposerEditor = require './composer-editor'
SendActionButton = require './send-action-button'
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
    draftClientId: React.PropTypes.string

    # Either "inline" or "fullwindow"
    mode: React.PropTypes.string

    # If this composer is part of an existing thread (like inline
    # composers) the threadId will be handed down
    threadId: React.PropTypes.string

    # Sometimes when changes in the composer happens it's desirable to
    # have the parent scroll to a certain location. A parent component can
    # pass a callback that gets called when this composer wants to be
    # scrolled to.
    scrollTo: React.PropTypes.func

  constructor: (@props) ->
    @state =
      draftReady: false
      to: []
      cc: []
      bcc: []
      from: []
      body: ""
      files: []
      uploads: []
      subject: ""
      accounts: []
      focusedField: Fields.To # Gets updated in @_initiallyFocusedField
      enabledFields: [] # Gets updated in @_initiallyEnabledFields
      showQuotedText: false

  componentWillMount: =>
    @_prepareForDraft(@props.draftClientId)

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidMount: =>
    @_usubs = []
    @_usubs.push AccountStore.listen @_onAccountStoreChanged
    @_applyFieldFocus()

  componentWillUnmount: =>
    @_unmounted = true # rarf
    @_teardownForDraft()
    @_deleteDraftIfEmpty()
    usub() for usub in @_usubs

  componentDidUpdate: (prevProps, prevState) =>
    # We want to use a temporary variable instead of putting this into the
    # state. This is because the selection is a transient property that
    # only needs to be applied once. It's not a long-living property of
    # the state. We could call `setState` here, but this saves us from a
    # re-rendering.
    @_recoveredSelection = null if @_recoveredSelection?

    # If the body changed, let's wait for the editor body to actually get rendered
    # into the dom before applying focus.
    # Since the editor is an InjectedComponent, when this function gets called
    # the editor hasn't actually finished rendering, so we need to wait for that
    # to happen by using the InjectedComponent's `onComponentDidRender` callback.
    # See `_renderEditor`
    bodyChanged = @state.body isnt prevState.body
    return if bodyChanged
    @_applyFieldFocus()

  focus: =>
    @_applyFieldFocus()

  _keymapHandlers: ->
    'composer:send-message': => @_onPrimarySend()
    'composer:delete-empty-draft': => @_deleteDraftIfEmpty()
    'composer:show-and-focus-bcc': =>
      @_onAdjustEnabledFields(show: [Fields.Bcc])
    'composer:show-and-focus-cc': =>
      @_onAdjustEnabledFields(show: [Fields.Cc])
    'composer:focus-to': =>
      @_onAdjustEnabledFields(show: [Fields.To])
    "composer:show-and-focus-from": => # TODO
    "composer:undo": @undo
    "composer:redo": @redo

  _applyFieldFocus: =>
    @_applyFieldFocusTo(@state.focusedField)

  _applyFieldFocusTo: (fieldName) =>
    return unless @refs[fieldName]

    $el = React.findDOMNode(@refs[fieldName])
    return if document.activeElement is $el or $el.contains(document.activeElement)
    if @refs[fieldName].focus
      @refs[fieldName].focus()
    else
      $el.select()
      $el.focus()

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
      if Utils.shouldDisplayAsImage(file)
        Actions.fetchFile(file)

  _teardownForDraft: =>
    unlisten() for unlisten in @unlisteners
    if @_proxy
      @_proxy.changes.commit()

  render: ->
    classes = "message-item-white-wrap composer-outer-wrap #{@props.className ? ""}"

    <KeyCommandsRegion
      localHandlers={@_keymapHandlers()}
      className={classes}
      onFocusIn={@_onFocusIn}
      tabIndex="-1"
      ref="composerWrap">
      {@_renderComposer()}
    </KeyCommandsRegion>

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

  _renderContent: =>
    <div className="composer-centered">
      {if @state.focusedField in Fields.ParticipantFields
        <ExpandedParticipants
          to={@state.to} cc={@state.cc} bcc={@state.bcc}
          from={@state.from}
          ref="expandedParticipants"
          mode={@props.mode}
          accounts={@state.accounts}
          draftReady={@state.draftReady}
          focusedField={@state.focusedField}
          enabledFields={@state.enabledFields}
          onPopoutComposer={@_onPopoutComposer}
          onChangeParticipants={@_onChangeParticipants}
          onChangeFocusedField={@_onChangeFocusedField}
          onAdjustEnabledFields={@_onAdjustEnabledFields} />
      else
        <CollapsedParticipants
          to={@state.to} cc={@state.cc} bcc={@state.bcc}
          onClick={@_onExpandParticipantFields} />
      }

      {@_renderSubject()}

      <div className="compose-body"
           ref="composeBody"
           onMouseUp={@_onMouseUpComposerBody}
           onMouseDown={@_onMouseDownComposerBody}>
        {@_renderBodyRegions()}
        {@_renderFooterRegions()}
      </div>
    </div>

  _onPopoutComposer: =>
    return unless @state.draftReady
    Actions.composePopoutDraft @props.draftClientId

  _onKeyDown: (event) =>
    if event.key is "Tab"
      @_onTabDown(event)
    return

  _onTabDown: (event) =>
    event.preventDefault()
    event.stopPropagation()
    @_onShiftFocusedField(if event.shiftKey then -1 else 1)

  _onShiftFocusedField: (dir) =>
    enabledFields = _.filter @state.enabledFields, (field) ->
      Fields.Order[field] >= 0
    enabledFields = _.sortBy enabledFields, (field) ->
      Fields.Order[field]
    i = enabledFields.indexOf @state.focusedField
    newI = Math.min(Math.max(i + dir, 0), enabledFields.length - 1)
    @_onChangeFocusedField(enabledFields[newI])

  _onChangeFocusedField: (focusedField) =>
    @setState({focusedField})
    if focusedField in Fields.ParticipantFields
      @_lastFocusedParticipantField = focusedField

  _onExpandParticipantFields: =>
    @_onChangeFocusedField(@_lastFocusedParticipantField ? Fields.To)

  _onAdjustEnabledFields: ({show, hide}={}) =>
    show = show ? []; hide = hide ? []
    enabledFields = _.difference(@state.enabledFields.concat(show), hide)

    if hide.length > 0 and enabledFields.indexOf(@state.focusedField) is -1
      @_onShiftFocusedField(-1)

    @setState({enabledFields})

    if show.length > 0
      @_onChangeFocusedField(show[0])

  _renderSubject: ->
    if Fields.Subject in @state.enabledFields
      <div key="subject-wrap" className="compose-subject-wrap">
        <input type="text"
               name="subject"
               ref={Fields.Subject}
               placeholder="Subject"
               value={@state.subject}
               onFocus={ => @setState(focusedField: Fields.Subject) }
               onChange={@_onChangeSubject}/>
      </div>

  _renderBodyRegions: =>
    <span ref="composerBodyWrap">
      {@_renderEditor()}
      {@_renderQuotedTextControl()}
      {@_renderAttachments()}
    </span>

  _renderEditor: ->
    exposedProps =
      body: @_removeQuotedText(@state.body)
      draftClientId: @props.draftClientId
      parentActions: {
        getComposerBoundingRect: @_getComposerBoundingRect
        scrollTo: @props.scrollTo
      }
      initialSelectionSnapshot: @_recoveredSelection
      onFocus: => @setState(focusedField: Fields.Body)
      onBlur: => @setState(focusedField: null)
      onFilePaste: @_onFilePaste
      onBodyChanged: @_onBodyChanged

    # TODO Get rid of the unecessary required methods:
    # getCurrentSelection and getPreviousSelection shouldn't be needed and
    # undo/redo functionality should be refactored into ComposerEditor
    # _onDOMMutated is just for testing purposes, refactor the tests
    <InjectedComponent
      ref={Fields.Body}
      matching={role: "Composer:Editor"}
      fallback={ComposerEditor}
      onComponentDidRender={@_onEditorBodyDidRender}
      requiredMethods={[
        'focus'
        'focusAbsoluteEnd'
        'getCurrentSelection'
        'getPreviousSelection'
        '_onDOMMutated'
      ]}
      exposedProps={exposedProps} />

  _onEditorBodyDidRender: =>
    @_applyFieldFocus()

  # The contenteditable decides when to request a scroll based on the
  # position of the cursor and its relative distance to this composer
  # component. We provide it our boundingClientRect so it can calculate
  # this value.
  _getComposerBoundingRect: =>
    React.findDOMNode(@refs.composerWrap).getBoundingClientRect()

  _removeQuotedText: (html) =>
    if @state.showQuotedText then return html
    else return QuotedHTMLTransformer.removeQuotedHTML(html)

  _showQuotedText: (html) =>
    if @state.showQuotedText then return html
    else return QuotedHTMLTransformer.appendQuotedHTML(html, @state.body)

  _renderQuotedTextControl: ->
    if QuotedHTMLTransformer.hasQuotedHTML(@state.body)
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
        exposedProps={draftClientId:@props.draftClientId, threadId: @props.threadId}
        direction="column"/>
    </div>

  _renderAttachments: ->
    <div className="attachments-area">
      {@_renderFileAttachments()}
      {@_renderUploadAttachments()}
    </div>

  _renderFileAttachments: ->
    nonImageFiles = @_nonImageFiles(@state.files).map((file) =>
      @_renderFileAttachment(file, "Attachment")
    )
    imageFiles = @_imageFiles(@state.files).map((file) =>
      @_renderFileAttachment(file, "Attachment:Image")
    )
    nonImageFiles.concat(imageFiles)

  _renderFileAttachment: (file, role) ->
    props =
      file: file
      removable: true
      targetPath: FileDownloadStore.pathForFile(file)
      messageClientId: @props.draftClientId

    if role is "Attachment"
      className = "file-wrap"
    else
      className = "file-wrap file-image-wrap"

    <InjectedComponent key={file.id}
                       matching={role: role}
                       className={className}
                       exposedProps={props} />

  _renderUploadAttachments: ->
    nonImageUploads = @_nonImageFiles(@state.uploads).map((upload) ->
      <FileUpload key={upload.id} upload={upload} />
    )
    imageUploads = @_imageFiles(@state.uploads).map((upload) ->
      <ImageFileUpload key={upload.id} upload={upload} />
    )
    nonImageUploads.concat(imageUploads)

  _imageFiles: (files) ->
    _.filter(files, Utils.shouldDisplayAsImage)

  _nonImageFiles: (files) ->
    _.reject(files, Utils.shouldDisplayAsImage)

  _renderActionsRegion: =>
    return <div></div> unless @props.draftClientId
    <div className="composer-action-bar-content">
      <InjectedComponentSet className="composer-action-bar-plugins"
                      matching={role: "Composer:ActionButton"}
                      exposedProps={draftClientId:@props.draftClientId, threadId: @props.threadId}></InjectedComponentSet>

      <button className="btn btn-toolbar btn-trash" style={order: 100}
              title="Delete draft"
              onClick={@_destroyDraft}><RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <button className="btn btn-toolbar btn-attach" style={order: 50}
              title="Attach file"
              onClick={@_selectAttachment}><RetinaImg name="icon-composer-attachment.png" mode={RetinaImg.Mode.ContentIsMask} /></button>

      <div style={order: 0, flex: 1} />

      <SendActionButton draft={@_proxy?.draft()}
                        ref="sendActionButton"
                        isValidDraft={@_isValidDraft} />

    </div>

  isForwardedMessage: =>
    return false if not @_proxy
    draft = @_proxy.draft()
    Utils.isForwardedMessage(draft)

  # This lets us click outside of the `contenteditable`'s `contentBody`
  # and simulate what happens when you click beneath the text *in* the
  # contentEditable.
  #
  # Unfortunately, we need to manually keep track of the "click" in
  # separate mouseDown, mouseUp events because we need to ensure that the
  # start and end target are both not in the contenteditable. This ensures
  # that this behavior doesn't interfear with a click and drag selection.
  _onMouseDownComposerBody: (event) =>
    if React.findDOMNode(@refs[Fields.Body]).contains(event.target)
      @_mouseDownTarget = null
    else @_mouseDownTarget = event.target

  _onMouseUpComposerBody: (event) =>
    if event.target is @_mouseDownTarget
      # We don't set state directly here because we want the native
      # contenteditable focus behavior. When the contenteditable gets focused
      # the focused field state will be properly set via editor.onFocus
      @refs[Fields.Body].focusAbsoluteEnd()
    @_mouseDownTarget = null

  # When a user focuses the composer, it's possible that no input is
  # initially focused. If this happens, we focus the contenteditable. If
  # we didn't focus the contenteditable, the user may start typing and
  # erroneously trigger keyboard shortcuts.
  _onFocusIn: (event) =>
    return if DOMUtils.closest(event.target, DOMUtils.inputTypes())
    @setState(focusedField: @_initiallyFocusedField(@_proxy.draft()))

  _onMouseMoveComposeBody: (event) =>
    if @_mouseComposeBody is "down" then @_mouseComposeBody = "move"

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
      uploads: draft.uploads
      subject: draft.subject
      accounts: @_getAccountsForSend()

    if !@state.draftReady
      _.extend state,
        draftReady: true
        focusedField: @_initiallyFocusedField(draft)
        enabledFields: @_initiallyEnabledFields(draft)
        showQuotedText: @isForwardedMessage()

    state = @_verifyEnabledFields(draft, state)

    @setState(state)

  _initiallyFocusedField: (draft) ->
    return Fields.To if draft.to.length is 0
    return Fields.Subject if (draft.subject ? "").trim().length is 0

    shouldFocusBody = @props.mode isnt 'inline' or draft.pristine or
      (FocusedContentStore.didFocusUsingClick('thread') is true)
    return Fields.Body if shouldFocusBody
    return null

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

  _getAccountsForSend: =>
    if @_proxy.draft()?.threadId
      [AccountStore.accountForId(@_proxy.draft().accountId)]
    else
      AccountStore.accounts()

  # When the account store changes, the From field may or may not still
  # be in scope. We need to make sure to update our enabled fields.
  _onAccountStoreChanged: =>
    accounts = @_getAccountsForSend()
    enabledFields = if @_shouldShowFromField(@_proxy?.draft())
      @state.enabledFields.concat [Fields.From]
    else
      _.without(@state.enabledFields, Fields.From)
    @setState {enabledFields, accounts}

  _shouldShowFromField: (draft) =>
    return true if draft
    return false

  _shouldEnableSubject: =>
    return false unless @_proxy
    draft = @_proxy.draft()
    if _.isEmpty(draft.subject ? "") then return true
    else if @isForwardedMessage() then return true
    else if draft.replyToMessageId then return false
    else return true

  _shouldAcceptDrop: (event) =>
    # Ensure that you can't pick up a file and drop it on the same draft
    nonNativeFilePath = @_nonNativeFilePathForDrop(event)

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
      Actions.addAttachment({filePath: file.path, messageClientId: @props.draftClientId})

    # Accept drops from attachment components / images within the app
    if (uri = @_nonNativeFilePathForDrop(e))
      Actions.addAttachment({filePath: uri, messageClientId: @props.draftClientId})

  _onFilePaste: (path) =>
    Actions.addAttachment({filePath: path, messageClientId: @props.draftClientId})

  _onChangeParticipants: (changes={}) =>
    @_addToProxy(changes)
    Actions.draftParticipantsChanged(@props.draftClientId, changes)

  _onChangeSubject: (event) =>
    @_addToProxy(subject: event.target.value)

  _onBodyChanged: (event) =>
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
    return unless @_proxy and @_proxy.draft()

    selections = @_getSelections()

    oldDraft = @_proxy.draft()
    return if _.all changes, (change, key) -> _.isEqual(change, oldDraft[key])

    # Other extensions might want to hear about changes immediately. We
    # only need to prevent this view from re-rendering until we're done
    # throttling body changes.
    if source.fromBodyChange then @_ignoreNextTrigger = true

    @_proxy.changes.add(changes)

    @_saveToHistory(selections) unless source.fromUndoManager

  _isValidDraft: (options = {}) =>
    return false unless @_proxy

    # We need to check the `DraftStore` because the `DraftStore` is
    # immediately and synchronously updated as soon as this function
    # fires. Since `setState` is asynchronous, if we used that as our only
    # check, then we might get a false reading.
    return false if DraftStore.isSendingDraft(@props.draftClientId)

    draft = @_proxy.draft()
    {remote} = require('electron')
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
        buttons: ['Edit Message', 'Cancel'],
        message: 'Cannot Send',
        detail: dealbreaker
      })
      return false

    bodyIsEmpty = draft.body is @_proxy.draftPristineBody()
    forwarded = Utils.isForwardedMessage(draft)
    hasAttachment = (draft.files ? []).length > 0 or (draft.uploads ? []).length > 0

    warnings = []

    if draft.subject.length is 0
      warnings.push('without a subject line')

    if @_mentionsAttachment(draft.body) and not hasAttachment
      warnings.push('without an attachment')

    if bodyIsEmpty and not forwarded and not hasAttachment
      warnings.push('without a body')

    # Check third party warnings added via Composer extensions
    for extension in ExtensionRegistry.Composer.extensions()
      continue unless extension.warningsForSending
      warnings = warnings.concat(extension.warningsForSending({draft}))

    if warnings.length > 0 and not options.force
      response = dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Send Anyway', 'Cancel'],
        message: 'Are you sure?',
        detail: "Send #{warnings.join(' and ')}?"
      })
      if response is 0 # response is button array index
        return @_isValidDraft({force: true})
      else return false

    return true

  _onPrimarySend: ->
    @refs["sendActionButton"].primaryClick()

  _mentionsAttachment: (body) =>
    body = QuotedHTMLTransformer.removeQuotedHTML(body.toLowerCase().trim())
    signatureIndex = body.indexOf('<div class="nylas-n1-signature">')
    body = body[...signatureIndex] if signatureIndex isnt -1
    return body.indexOf("attach") >= 0

  _destroyDraft: =>
    Actions.destroyDraft(@props.draftClientId)

  _selectAttachment: =>
    Actions.selectAttachment({messageClientId: @props.draftClientId})

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
