React = require 'react'
_ = require 'underscore'
EmailFrame = require './email-frame'
{Utils,
 MessageUtils,
 MessageBodyProcessor,
 QuotedHTMLTransformer,
 FileDownloadStore} = require 'nylas-exports'
{InjectedComponentSet} = require 'nylas-component-kit'

TransparentPixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNikAQAACIAHF/uBd8AAAAASUVORK5CYII="

class MessageItemBody extends React.Component
  @displayName: 'MessageItemBody'
  @propTypes:
    message: React.PropTypes.object.isRequired
    downloads: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state =
      showQuotedText: Utils.isForwardedMessage(@props.message)
      processedBody: undefined

  componentWillMount: =>
    @_unsub = MessageBodyProcessor.processAndSubscribe(@props.message, @_onBodyChanged)

  componentWillReceiveProps: (nextProps) ->
    if nextProps.message.id isnt @props.message.id
      @_unsub?()
      @_unsub = MessageBodyProcessor.processAndSubscribe(nextProps.message, @_onBodyChanged)

  componentWillUnmount: =>
    @_unsub?()

  render: =>
    <span>
      <InjectedComponentSet
        matching={role: "message:BodyHeader"}
        exposedProps={message: @props.message}
        direction="column"
        style={width:'100%'}/>
      {@_renderBody()}
      {@_renderQuotedTextControl()}
    </span>

  _renderBody: =>
    return null unless @state.processedBody?
    <EmailFrame showQuotedText={@state.showQuotedText} content={@state.processedBody}/>

  _renderQuotedTextControl: =>
    return null unless QuotedHTMLTransformer.hasQuotedHTML(@props.message.body)
    text = if @state.showQuotedText then "Hide" else "Show"
    <a className="quoted-text-control" onClick={@_toggleQuotedText}>
      <span className="dots">&bull;&bull;&bull;</span>{text} previous
    </a>

  _toggleQuotedText: =>
    @setState
      showQuotedText: !@state.showQuotedText

  _onBodyChanged: (body) =>
    downloadingSpinnerPath = Utils.imageNamed('inline-loading-spinner.gif')

    # Replace cid:// references with the paths to downloaded files
    for file in @props.message.files
      download = @props.downloads[file.id]
      cidRegexp = new RegExp("cid:#{file.contentId}(['\"]+)", 'gi')

      if download and download.state isnt 'finished'
        # Render a spinner and inject a `style` tag that injects object-position / object-fit
        body = body.replace cidRegexp, (text, quoteCharacter) ->
          "#{downloadingSpinnerPath}#{quoteCharacter} style=#{quoteCharacter} object-position: 50% 50%; object-fit: none; "
      else
        # Render the completed download
        body = body.replace cidRegexp, (text, quoteCharacter) ->
          "#{FileDownloadStore.pathForFile(file)}#{quoteCharacter}"

    # Replace remaining cid:// references - we will not display them since they'll
    # throw "unknown ERR_UNKNOWN_URL_SCHEME". Show a transparent pixel so that there's
    # no "missing image" region shown, just a space.
    body = body.replace(MessageUtils.cidRegex, "src=\"#{TransparentPixel}\"")

    @setState
      processedBody: body

module.exports = MessageItemBody
