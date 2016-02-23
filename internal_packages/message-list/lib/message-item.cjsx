React = require 'react'
classNames = require 'classnames'
_ = require 'underscore'
EmailFrame = require './email-frame'
MessageParticipants = require "./message-participants"
MessageItemBody = require "./message-item-body"
MessageTimestamp = require "./message-timestamp"
MessageControls = require './message-controls'
{Utils,
 Actions,
 MessageUtils,
 AccountStore,
 MessageStore,
 MessageBodyProcessor,
 QuotedHTMLTransformer,
 ComponentRegistry,
 FileDownloadStore} = require 'nylas-exports'
{RetinaImg,
 InjectedComponentSet,
 InjectedComponent} = require 'nylas-component-kit'

TransparentPixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNikAQAACIAHF/uBd8AAAAASUVORK5CYII="

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
            {@props.message.from?[0]?.displayName(compact: true)}
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
          <MessageItemBody message={@props.message} downloads={@state.downloads} />
          {@_renderAttachments()}
        </div>
      </div>
    </div>

  _renderHeader: =>
    classes = classNames
      "message-header": true
      "pending": @props.pending

    <header className={classes} onClick={@_onClickHeader}>
      {@_renderHeaderSideItems()}
      <div className="message-header-right">
        <InjectedComponentSet
          className="message-header-status"
          matching={role:"MessageHeaderStatus"}
          exposedProps={message: @props.message, thread: @props.thread, detailedHeaders: @state.detailedHeaders} />

        <MessageTimestamp className="message-time"
                          isDetailed={@state.detailedHeaders}
                          date={@props.message.date} />

        <MessageControls thread={@props.thread} message={@props.message}/>
      </div>
      {@_renderFromParticipants()}
      {@_renderToParticipants()}
      {@_renderFolder()}
      {@_renderHeaderDetailToggle()}
    </header>

  _renderFromParticipants: =>
    <MessageParticipants
      from={@props.message.from}
      onClick={@_onClickParticipants}
      isDetailed={@state.detailedHeaders} />

  _renderToParticipants: =>
    <MessageParticipants
      to={@props.message.to}
      cc={@props.message.cc}
      bcc={@props.message.bcc}
      onClick={@_onClickParticipants}
      isDetailed={@state.detailedHeaders} />

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

  _renderHeaderSideItems: ->
    styles =
      position: "absolute"
      marginTop: -2

    <div className="pending-spinner" style={styles}>
      <RetinaImg ref="spinner"
                 name="sending-spinner.gif"
                 mode={RetinaImg.Mode.ContentPreserve}/>
    </div>

  _renderHeaderDetailToggle: =>
    return null if @props.pending
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

  _toggleCollapsed: =>
    return if @props.isLastMsg
    Actions.toggleMessageIdExpanded(@props.message.id)

  _formatContacts: (contacts=[]) =>

  _attachmentComponents: =>
    imageAttachments = []
    otherAttachments = []

    for file in (@props.message.files ? [])
      continue unless @_isRealFile(file)
      if Utils.shouldDisplayAsImage(file)
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

  _isRealFile: (file) ->
    hasCIDInBody = file.contentId? and @props.message.body?.indexOf(file.contentId) > 0
    return not hasCIDInBody

  _onDownloadStoreChange: =>
    @setState
      downloads: FileDownloadStore.downloadDataForFiles(@props.message.fileIds())

module.exports = MessageItem
