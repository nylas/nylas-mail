React = require 'react'
_ = require 'underscore-plus'

{Actions,
 FileUploadStore,
 ComponentRegistry} = require 'inbox-exports'

FileUploads = require './file-uploads.cjsx'
DraftStoreProxy = require './draft-store-proxy'
ContenteditableToolbar = require './contenteditable-toolbar.cjsx'
ContenteditableComponent = require './contenteditable-component.cjsx'
ParticipantsTextField = require './participants-text-field.cjsx'


# The ComposerView is a unique React component because it (currently) is a
# singleton. Normally, the React way to do things would be to re-render the
# Composer with new props. As an alternative, we can call `setProps` to
# simulate the effect of the parent re-rendering us
module.exports =
ComposerView = React.createClass
  displayName: 'ComposerView'

  getInitialState: ->
    state = @getComponentRegistryState()
    _.extend state,
      populated: false
      to: []
      cc: []
      bcc: []
      body: ""
      subject: ""
    state

  getComponentRegistryState: ->
    ResizableComponent: ComponentRegistry.findViewByName 'ResizableComponent'
    AttachmentComponent: ComponentRegistry.findViewByName 'AttachmentComponent'
    FooterComponents: ComponentRegistry.findAllViewsByRole 'Composer:Footer'

  componentWillMount: ->
    @_prepareForDraft()

  componentDidMount: ->
    @keymap_unsubscriber = atom.commands.add '.composer-outer-wrap', {
      'composer:show-and-focus-bcc': @_showAndFocusBcc
      'composer:show-and-focus-cc': @_showAndFocusCc
      'composer:focus-to': => @focus "textFieldTo"
      'composer:send-message': => @_sendDraft()
    }
    if @props.mode is "fullwindow"
      # Need to delay so the component can be fully painted. Focus doesn't
      # work unless the element is on the page.
      _.delay =>
        @focus("textFieldTo")
      , 500

  componentWillUnmount: ->
    @_teardownForDraft()
    @keymap_unsubscriber.dispose()

  componentWillReceiveProps: (newProps) ->
    if newProps.localId != @props.localId
      # When we're given a new draft localId, we have to stop listening to our
      # current DraftStoreProxy, create a new one and listen to that. The simplest
      # way to do this is to just re-call registerListeners.
      @_teardownForDraft()
      @_prepareForDraft()

  _prepareForDraft: ->
    @_proxy = new DraftStoreProxy(@props.localId)

    @unlisteners = []
    @unlisteners.push @_proxy.listen(@_onDraftChanged)
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState(@getComponentRegistryState())

  _teardownForDraft: ->
    unlisten() for unlisten in @unlisteners
    @_proxy.changes.commit()

  render: ->
    ResizableComponent = @state.ResizableComponent

    if @props.mode is "inline" and ResizableComponent?
      <div className={@_wrapClasses()}>
        <ResizableComponent position="bottom" barStyle={bottom: "57px", zIndex: 2}>
          {@_renderComposer()}
        </ResizableComponent>
      </div>
    else
      <div className={@_wrapClasses()}>
        {@_renderComposer()}
      </div>

  _wrapClasses: ->
    "composer-outer-wrap #{@props.containerClass ? ""}"

  _renderComposer: ->
    <div className="composer-inner-wrap">
      <div className="composer-header">
        <div className="composer-title">
          Compose Message
        </div>
        <div className="composer-header-actions">
          <span
            className="header-action"
            style={display: @state.showcc and 'none' or 'inline'}
            onClick={=> @setState {showcc: true}}
            >Add cc/bcc</span>
          <span
            className="header-action"
            style={display: @state.showsubject and 'none' or 'initial'}
            onClick={=> @setState {showsubject: true}}
          >Change Subject</span>
          <span
            className="header-action"
            style={display: (@props.mode is "fullwindow") and 'none' or 'initial'}
            onClick={@_popoutComposer}
          >Popout&nbsp&nbsp;<i className="fa fa-expand"></i></span>
        </div>
      </div>

      <ParticipantsTextField
        ref="textFieldTo"
        field='to'
        change={@_proxy.changes.add}
        participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
        tabIndex='102'/>

      <ParticipantsTextField
        ref="textFieldCc"
        field='cc'
        visible={@state.showcc}
        change={@_proxy.changes.add}
        participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
        tabIndex='103'/>

      <ParticipantsTextField
        ref="textFieldBcc"
        field='bcc'
        visible={@state.showcc}
        change={@_proxy.changes.add}
        participants={to: @state['to'], cc: @state['cc'], bcc: @state['bcc']}
        tabIndex='104'/>

      <div className="compose-subject-wrap"
           style={display: @state.showsubject and 'initial' or 'none'}>
        <input type="text"
               key="subject"
               name="subject"
               placeholder="Subject"
               tabIndex="108"
               disabled={not @state.showsubject}
               className="compose-field compose-subject"
               defaultValue={@state.subject}
               onChange={@_onChangeSubject}/>
      </div>

      <div className="compose-body"
           onClick={=> @focus("contentBody")}>
        <ContenteditableComponent ref="contentBody"
                             onChange={@_onChangeBody}
                             html={@state.body}
                             tabIndex="109" />
      </div>

      <div className="attachments-area" >
        {@_fileComponents()}
        <FileUploads localId={@props.localId} />
      </div>

      <div className="compose-footer">
        <button className="btn btn-icon pull-right"
                onClick={@_destroyDraft}><i className="fa fa-trash"></i></button>
        <button className="btn btn-send"
                tabIndex="110"
                onClick={@_sendDraft}><i className="fa fa-send"></i>&nbsp;Send</button>
        <ContenteditableToolbar />
        <button className="btn btn-icon"
                onClick={@_attachFile}><i className="fa fa-paperclip"></i></button>
        {@_footerComponents()}
      </div>
    </div>

  focus: (field) -> @refs[field]?.focus?() if @isMounted()

  _footerComponents: ->
    (@state.FooterComponents ? []).map (Component) =>
      <Component draftLocalId={@props.localId} />

  _fileComponents: ->
    AttachmentComponent = @state.AttachmentComponent
    (@state.files ? []).map (file) =>
      <AttachmentComponent file={file}
                         removable={true}
                         messageLocalId={@props.localId} />

  _onDraftChanged: ->
    draft = @_proxy.draft()
    state =
      to: draft.to
      cc: draft.cc
      bcc: draft.bcc
      files: draft.files
      subject: draft.subject
      body: draft.body

    if !@state.populated
      _.extend state,
        showcc: (not (_.isEmpty(draft.cc) and _.isEmpty(draft.bcc)))
        showsubject: _.isEmpty(draft.subject)
        populated: true

    @setState(state)

  _onChangeSubject: (event) ->
    @_proxy.changes.add(subject: event.target.value)

  _onChangeBody: (event) ->
    @_proxy.changes.add(body: event.target.value)

  _popoutComposer: ->
    Actions.composePopoutDraft @props.localId

  _sendDraft: (options = {}) ->
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
    if draft.body.toLowerCase().indexOf('attachment') != -1 and draft.files?.length is 0
      warnings.push('without an attachment')

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

    @_proxy.changes.commit()
    Actions.sendDraft(@props.localId)

  _destroyDraft: ->
    Actions.destroyDraft(@props.localId)

  _attachFile: ->
    Actions.attachFile({messageLocalId: @props.localId})

  _showAndFocusBcc: ->
    @setState {showcc: true}
    @focus "textFieldBcc"

  _showAndFocusCc: ->
    @setState {showcc: true}
    @focus "textFieldCc"
