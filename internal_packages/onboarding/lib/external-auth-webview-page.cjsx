React = require 'react'
Page = require './page'
querystring = require 'querystring'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'

class ExternalAuthWebviewPage extends Page
  @displayName: "ExternalAuthWebviewPage"

  render: =>
    <div className="page no-top">
      {
        React.createElement('webview',{
          "ref": "connect-iframe",
          "src": @props.pageData.url
          "style": {position: "relative", zIndex: 1}
        })
      }
      {@_renderSpinner()}
      {@_renderAction()}
    </div>

  componentDidMount: =>
    @_listeners = {}
    webview = @refs['connect-iframe']
    return unless webview
    webview = React.findDOMNode(webview)
    @_setupWebviewListeners(webview)

  componentWillUnmount: ->
    webview = @refs['connect-iframe']
    webview = React.findDOMNode(webview)
    @_teardownWebviewListeners(webview)

  _fireMoveToPrevPage: =>
    OnboardingActions.moveToPreviousPage()

  _teardownWebviewListeners: (webview) ->
    for event, listener of @_listeners
      webview.removeEventListener event, listener

  _renderAction: ->
    if @props.pageData.noPreviousPage
      @_renderClose()
    else
      <div className="back" onClick={@_fireMoveToPrevPage}>
        <RetinaImg name="onboarding-back.png"
                   mode={RetinaImg.Mode.ContentPreserve}/>
      </div>

  _setupWebviewListeners: (webview) ->
    # Remove as soon as possible. Initial src is not correctly loaded
    # on webview, and this fixes it. Electron 0.26.0. (Still in 0.28.1)
    setTimeout ->
      webview.src = webview.src
    , 20

    @_listeners =
      "new-window": (e) ->
        require('shell').openExternal(e.url)
      "did-start-loading": (e) =>
        @_setUserAgent(e, webview)
      "did-finish-load": (e) =>
        @_onDidFinishLoad(e, webview)

    for event, listener of @_listeners
      webview.addEventListener event, listener

  _setUserAgent: (e, webview) ->
    if webview.hasMobileUserAgent is undefined
      webview.setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53")
      webview.hasMobileUserAgent = true
      webview.reload()

  _onDidFinishLoad: (e, webview) =>
    return unless webview

    # We can't use `setState` because that'll blow away the webview :(
    React.findDOMNode(@refs.spinner).style.visibility = "hidden"

    url = webview.getUrl()
    if url.indexOf('/connect/complete') != -1
      query = url.split('?')[1]
      query = query[0..-2] if query[query.length - 1] is '#'
      token = querystring.decode(query)

      EdgehillAPI.addTokens([token])
      OnboardingActions.moveToPage('add-account-success')
    else if url.indexOf('cancelled') != -1
      OnboardingActions.moveToPreviousPage()



module.exports = ExternalAuthWebviewPage
