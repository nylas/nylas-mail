React = require 'react'
classNames = require 'classnames'
_ = require 'underscore'
EmailFrame = require './email-frame'
MessageParticipants = require "./message-participants"
MessageTimestamp = require "./message-timestamp"
MessageControls = require './message-controls'
{Utils,
 Actions,
 MessageUtils,
 NamespaceStore,
 MessageStore,
 QuotedHTMLParser,
 ComponentRegistry,
 FileDownloadStore} = require 'nylas-exports'
{RetinaImg,
 InjectedComponentSet,
 InjectedComponent} = require 'nylas-component-kit'

TransparentPixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNikAQAACIAHF/uBd8AAAAASUVORK5CYII="
MessageBodyWidth = 740

class MessageItem extends React.Component
  @displayName = 'MessageItem'

  @propTypes =
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired
    collapsed: React.PropTypes.bool

  constructor: (@props) ->
    @state =
      # Holds the downloadData (if any) for all of our files. It's a hash
      # keyed by a fileId. The value is the downloadData.
      downloads: FileDownloadStore.downloadDataForFiles(@props.message.fileIds())
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
    attachmentIcon = []
    if @props.message.files.length > 0
      attachmentIcon = <div className="collapsed-attachment"></div>

    <div className={@props.className} onClick={@_toggleCollapsed}>
      <div className="message-item-white-wrap">
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
          {attachmentIcon}
        </div>
      </div>
    </div>

  _renderFull: =>
    <div className={@props.className}>
      <div className="message-item-white-wrap">
        <div className="message-item-area">
          {@_renderHeader()}
          <EmailFrame showQuotedText={@state.showQuotedText}>
            {@_formatBody()}
          </EmailFrame>
          <a className={@_quotedTextClasses()} onClick={@_toggleQuotedText}></a>
          {@_renderEvents()}
          {@_renderAttachments()}
        </div>
      </div>
    </div>

  _renderHeader: =>
    <header className="message-header" onClick={@_onClickHeader}>

      <div className="message-header-right">
        <MessageTimestamp className="message-time selectable"
                          isDetailed={@state.detailedHeaders}
                          date={@props.message.date} />

        <MessageControls thread={@props.thread} message={@props.message}/>

        <InjectedComponentSet className="message-indicator"
                              matching={role: "MessageIndicator"}
                              exposedProps={message: @props.message}/>
      </div>

      <MessageParticipants to={@props.message.to}
                           cc={@props.message.cc}
                           bcc={@props.message.bcc}
                           from={@props.message.from}
                           subject={@props.message.subject}
                           onClick={@_onClickParticipants}
                           isDetailed={@state.detailedHeaders}
                           message_participants={@props.message.participants()} />

      {@_renderFolder()}
      {@_renderHeaderExpansionControl()}

    </header>

  _renderFolder: =>
    return [] unless @state.detailedHeaders and @props.message.folder
    <div className="header-row">
      <div className="header-label">Folder:&nbsp;</div>
      <div className="header-name">{@props.message.folder.displayName}</div>
    </div>


  _onClickParticipants: (e) =>
    el = e.target
    while el isnt e.currentTarget
      if "collapsed-participants" in el.classList
        @setState(detailedHeaders: true)
        e.stopPropagation()
        return
      el = el.parentElement
    return

  _onClickHeader: (e) =>
    return if @state.detailedHeaders
    el = e.target
    while el isnt e.currentTarget
      wl = ["message-header-right",
            "collapsed-participants",
            "header-toggle-control"]
      if "message-header-right" in el.classList then return
      if "collapsed-participants" in el.classList then return
      el = el.parentElement
    @_toggleCollapsed()

  _renderAttachments: =>
    attachments = @_attachmentComponents()
    if attachments.length > 0
      <div className="attachments-area">{attachments}</div>
    else
      <div></div>

  _renderEvents: =>
    events = @_eventComponents()
    if events.length > 0 and not Utils.looksLikeGmailInvite(@props.message)
      <div className="events-area">{events}</div>
    else
      <div></div>

  _quotedTextClasses: => classNames
    "quoted-text-control": true
    'no-quoted-text': not QuotedHTMLParser.hasQuotedHTML(@props.message.body)
    'show-quoted-text': @state.showQuotedText

  _renderHeaderExpansionControl: =>
    if @state.detailedHeaders
      <div className="header-toggle-control"
           style={top: "18px", left: "-14px"}
           onClick={ (e) => @setState(detailedHeaders: false); e.stopPropagation()}>
        <RetinaImg name={"message-disclosure-triangle-active.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
    else
      <div className="header-toggle-control inactive"
           style={top: "18px"}
           onClick={ (e) => @setState(detailedHeaders: true); e.stopPropagation()}>
        <RetinaImg name={"message-disclosure-triangle.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>

  # Eventually, _formatBody will run a series of registered body transformers.
  # For now, it just runs a few we've hardcoded here, which are all synchronous.
  _formatBody: =>
    return "" unless @props.message and @props.message.body

    # Give each extension the message object to process the body, but don't
    # allow them to modify anything but the body for the time being.
    body = @props.message.body
    for extension in MessageStore.extensions()
      continue unless extension.formatMessageBody
      virtual = @props.message.clone()
      virtual.body = body
      extension.formatMessageBody(virtual)
      body = virtual.body

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
      continue if @state.downloads[file.id]
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
    return if @props.isLastMsg
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
        className="file-wrap"
        matching={role:"Attachment"}
        exposedProps={file:file, download: @state.downloads[file.id]}
        key={file.id}/>

    imageAttachments = imageAttachments.map (file) =>
      props =
        file: file
        download: @state.downloads[file.id]
        targetPath: FileDownloadStore.pathForFile(file)

      <InjectedComponent
        className="file-wrap file-image-wrap"
        matching={role:"Attachment:Image"}
        exposedProps={props}
        key={file.id} />

    return otherAttachments.concat(imageAttachments)

  _eventComponents: =>
    events = @props.message.events.map (e) =>
      <InjectedComponent
        className="event-wrap"
        matching={role:"Event"}
        exposedProps={event:e}
        key={e.id}/>

    return events

  _isRealFile: (file) ->
    hasCIDInBody = file.contentId? and @props.message.body?.indexOf(file.contentId) > 0
    return not hasCIDInBody

  _isForwardedMessage: =>
    Utils.isForwardedMessage(@props.message)

  _onDownloadStoreChange: =>
    @setState
      downloads: FileDownloadStore.downloadDataForFiles(@props.message.fileIds())

module.exports = MessageItem
