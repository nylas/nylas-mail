moment = require 'moment'
React = require 'react'
EmailFrame = require './email-frame'
MessageAttachment = require "./message-attachment.cjsx"
MessageParticipants = require "./message-participants.cjsx"
{FileDownloadStore, ComponentRegistry} = require 'inbox-exports'
Autolinker = require 'autolinker'

module.exports =
MessageItem = React.createClass
  displayName: 'MessageItem'

  getInitialState: ->
    # Holds the downloadData (if any) for all of our files. It's a hash
    # keyed by a fileId. The value is the downloadData.
    downloads: FileDownloadStore.downloadsForFiles(@_fileIds())
    showQuotedText: false
    collapsed: @props.collapsed

  componentDidMount: ->
    @_storeUnlisten = FileDownloadStore.listen(@_onFileDownloadStoreChange)

  componentWillUnmount: ->
    @_storeUnlisten() if @_storeUnlisten

  render: ->
    quotedTextClass = "quoted-text-toggle"
    quotedTextClass += " hidden" unless @_containsQuotedText()
    quotedTextClass += " state-" + @state.showQuotedText

    messageIndicators = ComponentRegistry.findAllViewsByRole('MessageIndicator')

    header =
      <header className="message-header" onClick={@_onToggleCollapsed}>
        <div className="message-time">{@_messageTime()}</div>
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
        <div className="attachments-area" style={display: @_hasAttachments()}>
          {@_attachmentCompontents()}
        </div>
        <EmailFrame showQuotedText={@state.showQuotedText}>
          {@_formatBody(@props.message.body)}
        </EmailFrame>
        <a className={quotedTextClass} onClick={@_toggleQuotedText}></a>
      </div>


  # Eventually, _formatBody will run a series of registered body transformers.
  # For now, it just runs a few we've hardcoded here, which are all synchronous.
  _formatBody: (body) ->
    return "" unless body
    formattedBody = Autolinker.link(body, {twitter: false})
    formattedBody

  _fileIds: ->
    (@props.message?.files ? []).map (file) -> file.id

  _containsQuotedText: ->
    # I know this is gross - one day we'll replace it with a nice system.
    body = @props.message.body
    return false unless body

    regexs = [/<blockquote/i, /\n[ ]*(>|&gt;)/, /<br[ ]*>[\n]?[ ]*[>|&gt;]/i, /.gmail_quote/]
    for regex in regexs
      return true if body.match(regex)
    return false

  _toggleQuotedText: ->
    @setState
      showQuotedText: !@state.showQuotedText

  _formatContacts: (contacts=[]) ->

  _attachmentCompontents: ->
    (@props.message.files ? []).map (file) =>
      <MessageAttachment file={file} downloadData={@state.downloads?[file.id] ? {}}/>

  _hasAttachments: ->
    if @props.message.files?.length > 0 then "block" else "none"

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

  _onFileDownloadStoreChange: ->
    # downloads is a hash keyed by the file id
    @setState downloads: FileDownloadStore.downloadsForFiles(@_fileIds())

  _onToggleCollapsed: ->
    @setState
      collapsed: !@state.collapsed
