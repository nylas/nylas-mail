React = require 'react'
_ = require 'underscore'
EmailFrame = require './email-frame'
{Utils,
 MessageUtils,
 MessageBodyProcessor,
 QuotedHTMLParser,
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

  componentWillReceiveProps: (newProps) =>
    @_unsub?()
    @_unsub = MessageBodyProcessor.processAndSubscribe(newProps.message, @_onBodyChanged)

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
    console.log(@state.processedBody)
    <EmailFrame showQuotedText={@state.showQuotedText} content={@state.processedBody}/>

  _renderQuotedTextControl: =>
    return null unless QuotedHTMLParser.hasQuotedHTML(@props.message.body)
    text = if @state.showQuotedText then "Hide" else "Show"
    <a className="quoted-text-control" onClick={@_toggleQuotedText}>
      <span className="dots">&bull;&bull;&bull;</span>{text} previous
    </a>

  _toggleQuotedText: =>
    @setState
      showQuotedText: !@state.showQuotedText

  _onBodyChanged: (body) =>
    # Replace cid:// references with the paths to downloaded files
    for file in @props.message.files
      continue if @props.downloads[file.id]
      cidLink = "cid:#{file.contentId}"
      fileLink = "#{FileDownloadStore.pathForFile(file)}"
      body = body.replace(cidLink, fileLink)

    # Replace remaining cid:// references - we will not display them since they'll
    # throw "unknown ERR_UNKNOWN_URL_SCHEME". Show a transparent pixel so that there's
    # no "missing image" region shown, just a space.
    body = body.replace(MessageUtils.cidRegex, "src=\"#{TransparentPixel}\"")

    @setState
      processedBody: body

module.exports = MessageItemBody
