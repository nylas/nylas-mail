React = require 'react'
_ = require 'underscore-plus'

{Utils,
 Actions,
 UndoManager,
 DraftStore,
 FileUploadStore} = require 'inbox-exports'

{ResizableRegion,
 InjectedComponentSet,
 InjectedComponent,
 RetinaImg} = require 'ui-components'

FileUploads = require './file-uploads'
ContenteditableComponent = require './contenteditable-component'
ParticipantsTextField = require './participants-text-field'

# The ComposerView is a unique React component because it (currently) is a
# singleton. Normally, the React way to do things would be to re-render the
# Composer with new props.
class ComposerView extends React.Component
  @displayName: 'ComposerView'

  constructor: (@props) ->
    @state =
      populated: false
      to: []
      cc: []
      bcc: []
      body: ""
      subject: ""
      showcc: false
      showbcc: false
      showsubject: false
      showQuotedText: false
      isSending: DraftStore.sendingState(@props.localId)

  componentWillMount: =>
    @_prepareForDraft(@props.localId)

  componentDidMount: =>
    @_draftStoreUnlisten = DraftStore.listen @_onSendingStateChanged
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
    @_teardownForDraft()
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
    @_proxy = DraftStore.sessionForLocalId(localId)
    @unlisteners.push @_proxy.listen(@_onDraftChanged)
    if @_proxy.draft()
      @_onDraftChanged()

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
                onClick={@_popoutComposer}><RetinaImg name="composer-popout.png" style={{position: "relative", top: "-2px"}}/></span>

        </div>

        <ParticipantsTextField
          ref="textFieldTo"
          field='to'
          visible={true}
          change={@_onChangeParticipants}
          participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
          tabIndex='102'/>

        <ParticipantsTextField
          ref="textFieldCc"
          field='cc'
          visible={@state.showcc}
          change={@_onChangeParticipants}
          onEmptied={=> @setState showcc: false}
          participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
          tabIndex='103'/>

        <ParticipantsTextField
          ref="textFieldBcc"
          field='bcc'
          visible={@state.showbcc}
          change={@_onChangeParticipants}
          onEmptied={=> @setState showbcc: false}
          participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
          tabIndex='104'/>

        <div className="compose-subject-wrap"
             style={display: @state.showsubject and 'initial' or 'none'}>
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

        <div className="compose-body">
          <ContenteditableComponent ref="contentBody"
                                    html={@state.body}
                                    onChange={@_onChangeBody}
                                    style={@_precalcComposerCss}
                                    initialSelectionSnapshot={@_recoveredSelection}
                                    mode={{showQuotedText: @state.showQuotedText}}
                                    onChangeMode={@_onChangeEditableMode}
                                    tabIndex="109" />
        </div>

        {@_renderFooterRegions()}
      </div>

      <div className="composer-action-bar-wrap">
        {@_renderActionsRegion()}
      </div>
    </div>

  _renderFooterRegions: =>
    return <div></div> unless @props.localId

    <span>
      <div className="attachments-area">
        {
          (@state.files ? []).map (file) =>
            <InjectedComponent name="Attachment"
                                 file={file}
                                 key={file.filename}
                                 removable={true}
                                 messageLocalId={@props.localId} />
        }
        <FileUploads localId={@props.localId} />
      </div>
      <InjectedComponentSet location="Composer:Footer" draftLocalId={@props.localId}/>
    </span>

  _renderActionsRegion: =>
    return <div></div> unless @props.localId

    <InjectedComponentSet className="composer-action-bar-content"
                      location="Composer:ActionButton"
                      draftLocalId={@props.localId}>

      <button className="btn btn-toolbar btn-trash" style={order: 100}
              data-tooltip="Delete draft"
              onClick={@_destroyDraft}><RetinaImg name="toolbar-trash.png" /></button>

      <button className="btn btn-toolbar btn-attach" style={order: 50}
              data-tooltip="Attach file"
              onClick={@_attachFile}><RetinaImg name="toolbar-attach.png"/></button>

      <div style={order: 0, flex: 1} />

      <button className="btn btn-toolbar btn-emphasis btn-send" style={order: -100}
              data-tooltip="Send message"
              ref="sendButton"
              onClick={@_sendDraft}><RetinaImg name="toolbar-send.png" /> Send</button>

    </InjectedComponentSet>

  # Focus the composer view. Chooses the appropriate field to start
  # focused depending on the draft type, or you can pass a field as
  # the first parameter.
  focus: (field = null) =>

    if component?.isForwardedMessage()
      field ?= "textFieldTo"
    else
      field ?= "contentBody"

    _.delay =>
      @refs[field]?.focus?()
    , 150

  isForwardedMessage: =>
    draft = @_proxy.draft()
    Utils.isForwardedMessage(draft)

  _onDraftChanged: =>
    draft = @_proxy.draft()
    if not @_initialHistorySave
      @_saveToHistory()
      @_initialHistorySave = true
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

  _onChangeParticipants: (changes={}) => @_addToProxy(changes)
  _onChangeSubject: (event) => @_addToProxy(subject: event.target.value)

  _onChangeBody: (event) =>
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
    @_proxy.changes.commit()
    Actions.composePopoutDraft @props.localId

  _sendDraft: (options = {}) =>
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

    warnings = []
    if draft.subject.length is 0
      warnings.push('without a subject line')
    if (draft.files ? []).length is 0 and @_hasAttachment(draft.body)
      warnings.push('without an attachment')

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

    Actions.sendDraft(@props.localId)

  _hasAttachment: (body) =>
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
    @setState isSending: DraftStore.sendingState(@props.localId)


  undo: (event) =>
    event.preventDefault()
    event.stopPropagation()
    historyItem = @undoManager.undo() ? {}
    return unless historyItem.state?

    @_recoveredSelection = historyItem.currentSelection
    @_addToProxy historyItem.state, fromUndoManager: true

  redo: (event) =>
    event.preventDefault()
    event.stopPropagation()
    historyItem = @undoManager.redo() ? {}
    return unless historyItem.state?

    @_recoveredSelection = historyItem.currentSelection
    @_addToProxy historyItem.state, fromUndoManager: true

  _getSelections: =>
    currentSelection: @refs.contentBody?.getCurrentSelection?()
    previousSelection: @refs.contentBody?.getPreviousSelection?()

  _saveToHistory: (selections) =>
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
    if @_proxy.draft().pristine then Actions.destroyDraft(@props.localId)


module.exports = ComposerView
