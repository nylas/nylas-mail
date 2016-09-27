React = require 'react'
_ = require 'underscore'
EmailFrame = require('./email-frame').default
{DraftHelpers,
 CanvasUtils,
 NylasAPI,
 MessageUtils,
 MessageBodyProcessor,
 QuotedHTMLTransformer,
 FileDownloadStore} = require 'nylas-exports'
{InjectedComponentSet, RetinaImg} = require 'nylas-component-kit'

TransparentPixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNikAQAACIAHF/uBd8AAAAASUVORK5CYII="

class MessageItemBody extends React.Component
  @displayName: 'MessageItemBody'
  @propTypes:
    message: React.PropTypes.object.isRequired
    downloads: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @_mounted = false
    @state =
      showQuotedText: DraftHelpers.isForwardedMessage(@props.message)
      processedBody: null
      error: null

  componentWillMount: =>
    @_unsub = MessageBodyProcessor.subscribe @props.message, (processedBody) =>
      @setState({processedBody})

  componentDidMount: =>
    @_mounted = true
    @_onFetchBody() if not _.isString(@props.message.body)

  componentWillReceiveProps: (nextProps) ->
    if nextProps.message.id isnt @props.message.id
      @_unsub?()
      @_unsub = MessageBodyProcessor.subscribe nextProps.message, (processedBody) =>
        @setState({processedBody})

  componentWillUnmount: =>
    @_mounted = false
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
    if _.isString(@props.message.body) and _.isString(@state.processedBody)
      <EmailFrame
        showQuotedText={@state.showQuotedText}
        content={@_mergeBodyWithFiles(@state.processedBody)}
        message={@props.message}
      />
    else if @state.error
      <div className="message-body-error">
        Sorry, this message could not be loaded. (Status code {@state.error.statusCode})
        <a onClick={@_onFetchBody}>Try Again</a>
      </div>
    else
      <div className="message-body-loading">
        <RetinaImg
          name="inline-loading-spinner.gif"
          mode={RetinaImg.Mode.ContentDark}
          style={{width: 14, height: 14}}/>
      </div>

  _renderQuotedTextControl: =>
    return null unless QuotedHTMLTransformer.hasQuotedHTML(@props.message.body)
    <a className="quoted-text-control" onClick={@_toggleQuotedText}>
      <span className="dots">&bull;&bull;&bull;</span>
    </a>

  _toggleQuotedText: =>
    @setState
      showQuotedText: !@state.showQuotedText

  _onFetchBody: =>
    NylasAPI.makeRequest
      path: "/messages/#{@props.message.id}"
      accountId: @props.message.accountId
      returnsModel: true
    .then =>
      return unless @_mounted
      @setState({error: null})
      # message will be put into the database and the MessageBodyProcessor
      # will provide us with the new body once it's been processed.
    .catch (error) =>
      return unless @_mounted
      @setState({error})

  _mergeBodyWithFiles: (body) =>
    # Replace cid: references with the paths to downloaded files
    for file in @props.message.files
      download = @props.downloads[file.id]

      cidRegexp = new RegExp("cid:#{file.contentId}(['\"]+)", 'gi')

      if download and download.state isnt 'finished'
        # Render a spinner and inject a `style` tag that injects object-position / object-fit
        body = body.replace cidRegexp, (text, quoteCharacter) ->
          dataUri = CanvasUtils.dataURIForLoadedPercent(download.percent)
          "#{dataUri}#{quoteCharacter} style=#{quoteCharacter} object-position: 50% 50%; object-fit: none; "
      else
        # Render the completed download
        body = body.replace cidRegexp, (text, quoteCharacter) ->
          "file://#{FileDownloadStore.pathForFile(file)}#{quoteCharacter}"

    # Replace remaining cid: references - we will not display them since they'll
    # throw "unknown ERR_UNKNOWN_URL_SCHEME". Show a transparent pixel so that there's
    # no "missing image" region shown, just a space.
    body = body.replace(MessageUtils.cidRegex, "src=\"#{TransparentPixel}\"")

    return body

module.exports = MessageItemBody
