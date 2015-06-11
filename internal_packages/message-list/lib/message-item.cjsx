React = require 'react'
classNames = require 'classnames'
_ = require 'underscore'
EmailFrame = require './email-frame'
MessageParticipants = require "./message-participants"
MessageTimestamp = require "./message-timestamp"
{Utils,
 Actions,
 NylasAPI,
 MessageUtils,
 ComponentRegistry,
 FileDownloadStore} = require 'nylas-exports'
{RetinaImg,
 InjectedComponentSet,
 InjectedComponent} = require 'nylas-component-kit'
Autolinker = require 'autolinker'
remote = require 'remote'

TransparentPixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNikAQAACIAHF/uBd8AAAAASUVORK5CYII="
MessageBodyWidth = 740

class MessageItem extends React.Component
  @displayName = 'MessageItem'

  @propTypes =
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired
    thread_participants: React.PropTypes.arrayOf(React.PropTypes.object)
    collapsed: React.PropTypes.bool

  constructor: (@props) ->
    @state =
      # Holds the downloadData (if any) for all of our files. It's a hash
      # keyed by a fileId. The value is the downloadData.
      downloads: FileDownloadStore.downloadsForFileIds(@props.message.fileIds())
      showQuotedText: @_isForwardedMessage()
      detailedHeaders: false

  componentDidMount: =>
    @_storeUnlisten = FileDownloadStore.listen(@_onDownloadStoreChange)

  componentWillUnmount: =>
    @_storeUnlisten() if @_storeUnlisten

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  render: =>
    if @props.collapsed
      @_renderCollapsed()
    else
      @_renderFull()

  _renderCollapsed: =>
    <div className={@props.className} onClick={@_toggleCollapsed}>
      <div className="message-item-area">
        <div className="collapsed-from">
          {@props.message.from?[0]?.displayFirstName()}
        </div>
        <div className="collapsed-snippet">
          {@props.message.snippet}
        </div>
        <div className="collapsed-timestamp">
          <MessageTimestamp date={@props.message.date} />
        </div>
      </div>
    </div>

  _renderFull: =>
    <div className={@props.className}>
      <div className="message-item-area">
        {@_renderHeader()}
        <EmailFrame showQuotedText={@state.showQuotedText}>
          {@_formatBody()}
        </EmailFrame>
        {@_renderAttachments()}
        <a className={@_quotedTextClasses()} onClick={@_toggleQuotedText}></a>
      </div>
    </div>

  _renderHeader: =>
    <header className="message-header">

      <div className="message-header-right">
        <MessageTimestamp className="message-time selectable"
                          isDetailed={@state.detailedHeaders}
                          date={@props.message.date} />

        <InjectedComponentSet className="message-indicator"
                              matching={role: "MessageIndicator"}
                              exposedProps={message: @props.message}/>

        {if @state.detailedHeaders then @_renderMessageActionsInline() else @_renderMessageActionsTooltip()}
      </div>

      <MessageParticipants to={@props.message.to}
                           cc={@props.message.cc}
                           bcc={@props.message.bcc}
                           from={@props.message.from}
                           subject={@props.message.subject}
                           onClick={=> @setState detailedHeaders: true}
                           thread_participants={@props.thread_participants}
                           isDetailed={@state.detailedHeaders}
                           message_participants={@props.message.participants()} />

      {@_renderCollapseControl()}

    </header>

  _renderAttachments: =>
    attachments = @_attachmentComponents()
    if attachments.length > 0
      <div className="attachments-area">{attachments}</div>
    else
      <div></div>

  _quotedTextClasses: => classNames
    "quoted-text-control": true
    'no-quoted-text': (Utils.quotedTextIndex(@props.message.body) is -1)
    'show-quoted-text': @state.showQuotedText

  _renderMessageActionsInline: =>
    @_renderMessageActions()

  _renderMessageActionsTooltip: =>
    return <span></span>
    ## TODO: For now leave blank. There may be an alternative UI in the
    #future.
    # <span className="msg-actions-tooltip"
    #       onClick={=> @setState detailedHeaders: true}>
    #   <RetinaImg name={"message-show-more.png"}/></span>

  _renderMessageActions: =>
    <div className="message-actions-wrap">
      <div className="message-actions-ellipsis" onClick={@_onShowActionsMenu}>
        <RetinaImg name={"message-actions-ellipsis.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
      <InjectedComponentSet className="message-actions"
                            inline={true}
                            matching={role:"MessageAction"}
                            exposedProps={thread:@props.thread, message: @props.message}>
        <button className="btn btn-icon" onClick={@_onReply}>
          <RetinaImg name={"message-reply.png"} mode={RetinaImg.Mode.ContentIsMask}/>
        </button>
        <button className="btn btn-icon" onClick={@_onReplyAll}>
          <RetinaImg name={"message-reply-all.png"} mode={RetinaImg.Mode.ContentIsMask}/>
        </button>
        <button className="btn btn-icon" onClick={@_onForward}>
          <RetinaImg name={"message-forward.png"} mode={RetinaImg.Mode.ContentIsMask}/>
        </button>
      </InjectedComponentSet>
    </div>

  _onReply: =>
    Actions.composeReply(thread: @props.thread, message: @props.message)

  _onReplyAll: =>
    Actions.composeReplyAll(thread: @props.thread, message: @props.message)

  _onForward: =>
    Actions.composeForward(thread: @props.thread, message: @props.message)

  _onReport: (issueType) =>
    {Contact, Message, DatabaseStore, NamespaceStore} = require 'nylas-exports'

    draft = new Message
      from: [NamespaceStore.current().me()]
      to: [new Contact(name: "Nylas Team", email: "feedback@nylas.com")]
      date: (new Date)
      draft: true
      subject: "Feedback - Message Display Issue (#{issueType})"
      namespaceId: NamespaceStore.current().id
      body: @props.message.body

    DatabaseStore.persistModel(draft).then =>
      DatabaseStore.localIdForModel(draft).then (localId) =>
        Actions.sendDraft(localId)

        dialog = remote.require('dialog')
        dialog.showMessageBox remote.getCurrentWindow(), {
          type: 'warning'
          buttons: ['OK'],
          message: "Thank you."
          detail: "The contents of this message have been sent to the Edgehill team and we added to a test suite."
        }

  _onShowOriginal: =>
    fs = require 'fs'
    path = require 'path'
    BrowserWindow = remote.require('browser-window')
    app = remote.require('app')
    tmpfile = path.join(app.getPath('temp'), @props.message.id)

    NylasAPI.makeRequest
      headers:
        Accept: 'message/rfc822'
      path: "/n/#{@props.message.namespaceId}/messages/#{@props.message.id}"
      json:null
      success: (body) =>
        fs.writeFile tmpfile, body, =>
          window = new BrowserWindow(width: 800, height: 600, title: "#{@props.message.subject} - RFC822")
          window.loadUrl('file://'+tmpfile)

  _onShowActionsMenu: =>
    remote = require('remote')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    # Todo: refactor this so that message actions are provided
    # dynamically. Waiting to see if this will be used often.
    menu = new Menu()
    menu.append(new MenuItem({ label: 'Report Issue: Quoted Text', click: => @_onReport('Quoted Text')}))
    menu.append(new MenuItem({ label: 'Report Issue: Rendering', click: => @_onReport('Rendering')}))
    menu.append(new MenuItem({ type: 'separator'}))
    menu.append(new MenuItem({ label: 'Show Original', click: => @_onShowOriginal()}))
    menu.popup(remote.getCurrentWindow())

  _renderCollapseControl: =>
    if @state.detailedHeaders
      <div className="collapse-control"
           style={top: "4px", left: "-17px"}
           onClick={=> @setState detailedHeaders: false}>
        <RetinaImg name={"message-disclosure-triangle-active.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
    else
      <div className="collapse-control inactive"
           style={top: "3px"}
           onClick={=> @setState detailedHeaders: true}>
        <RetinaImg name={"message-disclosure-triangle.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>

  # Eventually, _formatBody will run a series of registered body transformers.
  # For now, it just runs a few we've hardcoded here, which are all synchronous.
  _formatBody: =>
    return "" unless @props.message and @props.message.body

    body = @props.message.body

    # Apply the autolinker pass to make emails and links clickable
    body = Autolinker.link(body, {twitter: false})

    # Find inline images and give them a calculated CSS height based on
    # html width and height, when available. This means nothing changes size
    # as the image is loaded, and we can estimate final height correctly.
    # Note that MessageBodyWidth must be updated if the UI is changed!

    while (result = MessageUtils.cidRegex.exec(body)) isnt null
      imgstart = body.lastIndexOf('<', result.index)
      imgend = body.indexOf('/>', result.index)

      if imgstart != -1 and imgend > imgstart
        imgtag = body.substr(imgstart, imgend - imgstart)
        width = imgtag.match(/width[ ]?=[ ]?['"]?(\d*)['"]?/)?[1]
        height = imgtag.match(/height[ ]?=[ ]?['"]?(\d*)['"]?/)?[1]
        if width and height
          scale = Math.min(1, MessageBodyWidth / width)
          style = " style=\"height:#{height * scale}px;\" "
          body = body.substr(0, imgend) + style + body.substr(imgend)

    # Replace cid:// references with the paths to downloaded files
    for file in @props.message.files
      continue if _.find @state.downloads, (d) -> d.fileId is file.id
      cidLink = "cid:#{file.contentId}"
      fileLink = "#{FileDownloadStore.pathForFile(file)}"
      body = body.replace(cidLink, fileLink)

    # Replace remaining cid:// references - we will not display them since they'll
    # throw "unknown ERR_UNKNOWN_URL_SCHEME". Show a transparent pixel so that there's
    # no "missing image" region shown, just a space.
    body = body.replace(MessageUtils.cidRegex, "src=\"#{TransparentPixel}\"")

    body

  _toggleQuotedText: =>
    @setState
      showQuotedText: !@state.showQuotedText

  _toggleCollapsed: =>
    Actions.toggleMessageIdExpanded(@props.message.id)

  _formatContacts: (contacts=[]) =>

  _attachmentComponents: =>
    imageAttachments = []
    otherAttachments = []

    for file in (@props.message.files ? [])
      continue unless @_isRealFile(file)
      if Utils.looksLikeImage(file)
        imageAttachments.push(file)
      else
        otherAttachments.push(file)

    otherAttachments = otherAttachments.map (file) =>
      <InjectedComponent
        className="attachment-file-wrap"
        matching={role:"Attachment"}
        exposedProps={file:file, download: @state.downloads[file.id]}
        key={file.id}/>

    imageAttachments = imageAttachments.map (file) =>
      props =
        file: file
        download: @state.downloads[file.id]
        targetPath: FileDownloadStore.pathForFile(file)

      <InjectedComponent
        className="image-attachment-file-wrap"
        matching={role:"Attachment:Image"}
        exposedProps={props}
        key={file.id} />

    return otherAttachments.concat(imageAttachments)

  # We ignore files with no name because they're actually mime-parts of the
  # message being served by the API as files.
  _isRealFile: (file) ->
    hasName = file.filename and file.filename.length > 0
    hasCIDInBody = file.contentId? and @props.message.body?.indexOf(file.contentId) > 0
    return hasName and not hasCIDInBody

  _isForwardedMessage: =>
    Utils.isForwardedMessage(@props.message)

  _onDownloadStoreChange: =>
    @setState
      downloads: FileDownloadStore.downloadsForFileIds(@props.message.fileIds())

module.exports = MessageItem
