moment = require 'moment'
React = require 'react'
_ = require 'underscore-plus'
EmailFrame = require './email-frame'
MessageParticipants = require "./message-participants.cjsx"
{ComponentRegistry, FileDownloadStore, Utils} = require 'inbox-exports'
Autolinker = require 'autolinker'

module.exports =
MessageItem = React.createClass
  displayName: 'MessageItem'
  propTypes:
    message: React.PropTypes.object.isRequired,
    collapsed: React.PropTypes.bool
    thread_participants: React.PropTypes.arrayOf(React.PropTypes.object),

  mixins: [ComponentRegistry.Mixin]
  components: ['AttachmentComponent']

  getInitialState: ->
    # Holds the downloadData (if any) for all of our files. It's a hash
    # keyed by a fileId. The value is the downloadData.
    downloads: FileDownloadStore.downloadsForFileIds(@props.message.fileIds())
    showQuotedText: false
    collapsed: @props.collapsed

  componentDidMount: ->
    @_storeUnlisten = FileDownloadStore.listen(@_onDownloadStoreChange)

  componentWillUnmount: ->
    @_storeUnlisten() if @_storeUnlisten

  render: ->
    quotedTextClass = React.addons.classSet
      "quoted-text-toggle": true
      'hidden': !Utils.containsQuotedText(@props.message.body)
      'state-on': @state.showQuotedText

    messageActions = ComponentRegistry.findAllViewsByRole('MessageAction')
    messageIndicators = ComponentRegistry.findAllViewsByRole('MessageIndicator')
    attachments = @_attachmentComponents()
    if attachments.length > 0
      attachments = <div className="attachments-area">{attachments}</div>

    header =
      <header className="message-header" onClick={@_onToggleCollapsed}>
        <div className="message-time">{@_messageTime()}</div>
        <div className="message-actions">
          {<Action thread={@props.thread} message={@props.message} /> for Action in messageActions}
        </div>
        {<div className="message-indicator"><Indicator message={@props.message}/></div> for Indicator in messageIndicators}
        <MessageParticipants to={@props.message.to}
                             cc={@props.message.cc}
                             from={@props.message.from}
                             thread_participants={@props.thread_participants}
                             message_participants={@props.message.participants()} />
      </header>

    if @state.collapsed
      <div className="message-item-wrap collapsed">
        {header}
      </div>
    else
      <div className="message-item-wrap">
        {header}
        {attachments}
        <EmailFrame showQuotedText={@state.showQuotedText}>
          {@_formatBody()}
        </EmailFrame>
        <a className={quotedTextClass} onClick={@_toggleQuotedText}></a>
      </div>


  # Eventually, _formatBody will run a series of registered body transformers.
  # For now, it just runs a few we've hardcoded here, which are all synchronous.
  _formatBody: ->
    return "" unless @props.message

    body = @props.message.body

    # Apply the autolinker pass to make emails and links clickable
    body = Autolinker.link(body, {twitter: false})

    # Find cid:// references and replace them with the paths to downloaded files
    for file in @props.message.files
      continue if _.find @state.downloads, (d) -> d.fileId is file.id
      cidLink = "cid:#{file.contentId}"
      fileLink = "#{FileDownloadStore.pathForFile(file)}"
      body = body.replace(cidLink, fileLink)

    # Remove any remaining cid:// references - we will not display them since they'll
    # throw "unknown ERR_UNKNOWN_URL_SCHEME"
    body = body.replace(/src=['"]cid:[^'"]*['"]/g, '')

    body

  _toggleQuotedText: ->
    @setState
      showQuotedText: !@state.showQuotedText

  _formatContacts: (contacts=[]) ->

  _attachmentComponents: ->
    AttachmentComponent = @state.AttachmentComponent
    attachments = _.filter @props.message.files, (f) -> not f.contentId?
    attachments.map (file) =>
      <AttachmentComponent file={file} download={@state.downloads[file.id]}/>

  _messageTime: ->
    moment(@props.message.date).format(@_timeFormat())

  _timeFormat: ->
    today = moment(@_today())
    dayOfEra = today.dayOfYear() + today.year() * 365
    msgDate = moment(@props.message.date)
    msgDayOfEra = msgDate.dayOfYear() + msgDate.year() * 365
    diff = dayOfEra - msgDayOfEra
    if diff < 1
      return "h:mm a"
    if diff < 4
      return "MMM D, h:mm a"
    else if diff > 1 and diff <= 365
      return "MMM D"
    else
      return "MMM D YYYY"

  # Stubbable for testing. Returns a `moment`
  _today: -> moment()

  _onDownloadStoreChange: ->
    @setState
      downloads: FileDownloadStore.downloadsForFileIds(@props.message.fileIds())

  _onToggleCollapsed: ->
    @setState
      collapsed: !@state.collapsed
