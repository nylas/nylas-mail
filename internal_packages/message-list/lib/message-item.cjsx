React = require 'react'
_ = require 'underscore-plus'
EmailFrame = require './email-frame'
MessageParticipants = require "./message-participants.cjsx"
MessageTimestamp = require "./message-timestamp.cjsx"
{ComponentRegistry, FileDownloadStore, Utils, Actions} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'
Autolinker = require 'autolinker'

TransparentPixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNikAQAACIAHF/uBd8AAAAASUVORK5CYII="
MessageBodyWidth = 740

module.exports =
MessageItem = React.createClass
  displayName: 'MessageItem'

  propTypes:
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired
    thread_participants: React.PropTypes.arrayOf(React.PropTypes.object)
    collapsed: React.PropTypes.bool

  mixins: [ComponentRegistry.Mixin]
  components: ['AttachmentComponent']

  getInitialState: ->
    # Holds the downloadData (if any) for all of our files. It's a hash
    # keyed by a fileId. The value is the downloadData.
    downloads: FileDownloadStore.downloadsForFileIds(@props.message.fileIds())
    showQuotedText: @_isForwardedMessage()
    detailedHeaders: false

  componentDidMount: ->
    @_storeUnlisten = FileDownloadStore.listen(@_onDownloadStoreChange)

  componentWillUnmount: ->
    @_storeUnlisten() if @_storeUnlisten

  shouldComponentUpdate: (nextProps, nextState) ->
    not _.isEqual(nextProps, @props) or not _.isEqual(nextState, @state)

  render: ->
    messageIndicators = ComponentRegistry.findAllViewsByRole('MessageIndicator')
    attachments = @_attachmentComponents()
    if attachments.length > 0
      attachments = <div className="attachments-area">{attachments}</div>

    header =
      <header className="message-header">

        <div className="message-header-right">
          <MessageTimestamp className="message-time"
                            isDetailed={@state.detailedHeaders}
                            date={@props.message.date} />

          {<div className="message-indicator"><Indicator message={@props.message}/></div> for Indicator in messageIndicators}

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

    <div className={@props.className}>
      <div className="message-item-area">
        {header}
        {attachments}
        <EmailFrame showQuotedText={@state.showQuotedText}>
          {@_formatBody()}
        </EmailFrame>
        <a className={@_quotedTextClasses()} onClick={@_toggleQuotedText}></a>
      </div>
    </div>

  _quotedTextClasses: -> React.addons.classSet
    "quoted-text-control": true
    'no-quoted-text': (Utils.quotedTextIndex(@props.message.body) is -1)
    'show-quoted-text': @state.showQuotedText

  _renderMessageActionsInline: ->
    @_renderMessageActions()

  _renderMessageActionsTooltip: ->
    ## TODO: Use Tooltip UI Component
    <span className="msg-actions-tooltip"
          onClick={=> @setState detailedHeaders: true}>
      <RetinaImg name={"message-show-more.png"}/></span>

  _renderMessageActions: ->
    messageActions = ComponentRegistry.findAllViewsByRole('MessageAction')
    <div className="message-actions">
      <button className="btn btn-icon" onClick={@_onReply}>
        <RetinaImg name={"message-reply.png"}/>
      </button>
      <button className="btn btn-icon" onClick={@_onReplyAll}>
        <RetinaImg name={"message-reply-all.png"}/>
      </button>
      <button className="btn btn-icon" onClick={@_onForward}>
        <RetinaImg name={"message-forward.png"}/>
      </button>

      {<Action thread={@props.thread} message={@props.message} /> for Action in messageActions}

    </div>

  _onReply: ->
    tId = @props.thread.id; mId = @props.message.id
    Actions.composeReply(threadId: tId, messageId: mId) if (tId and mId)

  _onReplyAll: ->
    tId = @props.thread.id; mId = @props.message.id
    Actions.composeReplyAll(threadId: tId, messageId: mId) if (tId and mId)

  _onForward: ->
    tId = @props.thread.id; mId = @props.message.id
    Actions.composeForward(threadId: tId, messageId: mId) if (tId and mId)

  _renderCollapseControl: ->
    if @state.detailedHeaders
      <div className="collapse-control"
           style={top: "-1px", left: "-17px"}
           onClick={=> @setState detailedHeaders: false}>
        <RetinaImg name={"message-disclosure-triangle-active.png"}/>
      </div>
    else
      <div className="collapse-control inactive"
           style={top: "-2px"}
           onClick={=> @setState detailedHeaders: true}>
        <RetinaImg name={"message-disclosure-triangle.png"}/>
      </div>

  # Eventually, _formatBody will run a series of registered body transformers.
  # For now, it just runs a few we've hardcoded here, which are all synchronous.
  _formatBody: ->
    return "" unless @props.message

    body = @props.message.body

    # Apply the autolinker pass to make emails and links clickable
    body = Autolinker.link(body, {twitter: false})

    # Find inline images and give them a calculated CSS height based on
    # html width and height, when available. This means nothing changes size
    # as the image is loaded, and we can estimate final height correctly.
    # Note that MessageBodyWidth must be updated if the UI is changed!

    cidRegex = /src=['"]cid:([^'"]*)['"]/g
    while (result = cidRegex.exec(body)) isnt null
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
    body = body.replace(/src=['"]cid:[^'"]*['"]/g, "src=\"#{TransparentPixel}\"")

    body

  _toggleQuotedText: ->
    @setState
      showQuotedText: !@state.showQuotedText

  _formatContacts: (contacts=[]) ->

  _attachmentComponents: ->
    AttachmentComponent = @state.AttachmentComponent
    attachments = _.filter @props.message.files, (f) =>
      inBody = f.contentId? and @props.message.body.indexOf(f.contentId) > 0
      not inBody and f.filename.length > 0

    attachments.map (file) =>
      <AttachmentComponent file={file} key={file.id} download={@state.downloads[file.id]}/>

  _isForwardedMessage: ->
    Utils.isForwardedMessage(@props.message.body, @props.message.subject)

  _onDownloadStoreChange: ->
    @setState
      downloads: FileDownloadStore.downloadsForFileIds(@props.message.fileIds())
