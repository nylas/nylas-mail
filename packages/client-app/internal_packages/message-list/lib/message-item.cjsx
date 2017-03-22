React = require 'react'
ReactDOM = require 'react-dom'
classNames = require 'classnames'
_ = require 'underscore'
MessageParticipants = require "./message-participants"
MessageItemBody = require "./message-item-body"
MessageTimestamp = require("./message-timestamp").default
MessageControls = require './message-controls'
{Utils,
 Actions,
 MessageUtils,
 AccountStore,
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
    messages: React.PropTypes.array.isRequired
    collapsed: React.PropTypes.bool
    onLoad: React.PropTypes.func

  constructor: (@props) ->
    fileIds = @props.message.fileIds()
    @state =
      # Holds the downloadData (if any) for all of our files. It's a hash
      # keyed by a fileId. The value is the downloadData.
      downloads: FileDownloadStore.getDownloadDataForFiles(fileIds)
      filePreviewPaths: FileDownloadStore.previewPathsForFiles(fileIds)
      detailedHeaders: false
      detailedHeadersTogglePos: {top: 18}

  componentDidMount: =>
    @_storeUnlisten = FileDownloadStore.listen(@_onDownloadStoreChange)
    @_setDetailedHeadersTogglePos()

  componentDidUpdate: =>
    @_setDetailedHeadersTogglePos()

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
    if Utils.showIconForAttachments(@props.message.files)
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
          <MessageItemBody
            message={@props.message}
            downloads={@state.downloads}
            onLoad={@props.onLoad}
          />
          {@_renderAttachments()}
          {@_renderFooterStatus()}
        </div>
      </div>
    </div>

  _renderHeader: =>
    classes = classNames
      "message-header": true
      "pending": @props.pending

    <header ref="header" className={classes} onClick={@_onClickHeader}>
      <InjectedComponent
        matching={{role: "MessageHeader"}}
        exposedProps={{message: @props.message, thread: @props.thread, messages: @props.messages}}
      />
      <div className="pending-spinner" style={{position: 'absolute', marginTop: -2}}>
        <RetinaImg
          ref="spinner"
          name="sending-spinner.gif"
          mode={RetinaImg.Mode.ContentPreserve}
        />
      </div>
      <div className="message-header-right">
        <MessageTimestamp
          className="message-time"
          isDetailed={@state.detailedHeaders}
          date={@props.message.date}
        />
        <InjectedComponentSet
          className="message-header-status"
          matching={role: "MessageHeaderStatus"}
          exposedProps={message: @props.message, thread: @props.thread, detailedHeaders: @state.detailedHeaders}
        />
        <MessageControls thread={@props.thread} message={@props.message}/>
      </div>
      <MessageParticipants
        from={@props.message.from}
        onClick={@_onClickParticipants}
        isDetailed={@state.detailedHeaders}
      />
      <MessageParticipants
        to={@props.message.to}
        cc={@props.message.cc}
        bcc={@props.message.bcc}
        onClick={@_onClickParticipants}
        isDetailed={@state.detailedHeaders}
      />
      {@_renderFolder()}
      {@_renderHeaderDetailToggle()}
    </header>

  _renderFolder: =>
    return [] unless @state.detailedHeaders
    acct = AccountStore.accountForId(@props.message.accountId)
    acctUsesFolders = acct and acct.usesFolders()
    folder = @props.message.categories?[0]
    return unless folder and acctUsesFolders
    <div className="header-row">
      <div className="header-label">Folder:&nbsp;</div>
      <div className="header-name">{folder.displayName}</div>
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

  _onDownloadAll: =>
    Actions.fetchAndSaveAllFiles(@props.message.files)

  _renderDownloadAllButton: =>
    <div className="download-all">
      <div className="attachment-number">
        <RetinaImg
          name="ic-attachments-all-clippy.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
        <span>{@props.message.files.length} attachments</span>
      </div>
      <div className="separator">-</div>
      <div className="download-all-action" onClick={@_onDownloadAll}>
        <RetinaImg
          name="ic-attachments-download-all.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
        <span>Download all</span>
      </div>
    </div>


  _renderAttachments: =>
    files = (@props.message.files ? []).filter((f) => @_isRealFile(f))
    messageClientId = @props.message.clientId
    {filePreviewPaths, downloads} = @state
    if files.length > 0
      <div>
        {if files.length > 1 then @_renderDownloadAllButton()}
        <div className="attachments-area">
          <InjectedComponent
            matching={{role: 'MessageAttachments'}}
            exposedProps={{files, downloads, filePreviewPaths, messageClientId, canRemoveAttachments: false}}
          />
        </div>
      </div>
    else
      <div />

  _renderFooterStatus: =>
    <InjectedComponentSet
      className="message-footer-status"
      matching={role:"MessageFooterStatus"}
      exposedProps={message: @props.message, thread: @props.thread, detailedHeaders: @state.detailedHeaders}
    />

  _setDetailedHeadersTogglePos: =>
    header = ReactDOM.findDOMNode(@refs.header)
    if !header
      return
    fromNode = header.querySelector('.participant-name.from-contact,.participant-primary')
    if !fromNode
      return
    fromRect = fromNode.getBoundingClientRect()
    topPos = Math.floor(fromNode.offsetTop + (fromRect.height / 2) - 10)
    if topPos isnt @state.detailedHeadersTogglePos.top
      @setState({detailedHeadersTogglePos: {top: topPos}})

  _renderHeaderDetailToggle: =>
    return null if @props.pending
    {top} = @state.detailedHeadersTogglePos
    if @state.detailedHeaders
      <div
        className="header-toggle-control"
        style={{top, left: "-14px"}}
        onClick={(e) => @setState(detailedHeaders: false); e.stopPropagation()}
      >
        <RetinaImg
          name={"message-disclosure-triangle-active.png"}
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </div>
    else
      <div
        className="header-toggle-control inactive"
        style={{top}}
        onClick={(e) => @setState(detailedHeaders: true); e.stopPropagation()}
      >
        <RetinaImg
          name={"message-disclosure-triangle.png"}
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </div>

  _toggleCollapsed: =>
    return if @props.isLastMsg
    Actions.toggleMessageIdExpanded(@props.message.id)

  _isRealFile: (file) ->
    hasCIDInBody = file.contentId? and @props.message.body?.indexOf(file.contentId) > 0
    return not hasCIDInBody

  _onDownloadStoreChange: =>
    fileIds = @props.message.fileIds()
    @setState
      downloads: FileDownloadStore.getDownloadDataForFiles(fileIds)
      filePreviewPaths: FileDownloadStore.previewPathsForFiles(fileIds)

module.exports = MessageItem
