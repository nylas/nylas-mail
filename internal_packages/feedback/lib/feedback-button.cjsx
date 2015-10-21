{Utils,
 React,
 FocusedContactsStore,
 AccountStore,
 Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'
FeedbackActions = require './feedback-actions'

class FeedbackButton extends React.Component
  @displayName: 'FeedbackButton'

  constructor: (@props) ->
    @state = {newMessages: false}

  componentDidMount: =>
    @_unsubs = []
    @_unsubs.push Actions.sendFeedback.listen(@_onSendFeedback)
    @_unsubs.push FeedbackActions.feedbackAvailable.listen(@_onFeedbackAvailable)

  componentWillUnmount: =>
    unsub() for unsub in @_unsubs

  render: =>
    <div style={position:"absolute",height:0} title="Help & Feedback">
      <div className={@_getClassName()} onClick={@_onSendFeedback}>?</div>
    </div>

  _getClassName: =>
    return "btn-feedback" + if @state.newMessages then " newmsg" else ""

  _onFeedbackAvailable: =>
    @setState(newMessages: true)

  _onSendFeedback: =>
    return if atom.inSpecMode()

    BrowserWindow = require('remote').require('browser-window')
    Screen = require('remote').require('screen')
    path = require 'path'
    qs = require 'querystring'

    @setState(newMessages: false)

    if window.feedbackWindow?
      window.feedbackWindow.show()
    else

      account = AccountStore.current()
      params = qs.stringify({
        name: account.name
        email: account.emailAddress
        accountId: account.id
        accountProvider: account.provider
        platform: process.platform
        provider: account.displayProvider()
        organizational_unit: account.organizationUnit
        version: atom.getVersion()
      })

      parentBounds = atom.getCurrentWindow().getBounds()
      parentScreen = Screen.getDisplayMatching(parentBounds)

      width = 376
      height = Math.min(550, parentBounds.height)
      x = Math.min(parentScreen.workAreaSize.width - width, Math.max(0, parentBounds.x + parentBounds.width - 36 - width / 2))
      y = Math.max(0, (parentBounds.y + parentBounds.height) - height - 60)

      window.feedbackWindow = w = new BrowserWindow
        'node-integration': false,
        'web-preferences': {'web-security':false},
        'x': x
        'y': y
        'width': width,
        'height': height,
        'title': 'Feedback'

      # Disable window close, hide instead
      w.on 'close', (event) ->
        # inside the window we prevent close - here we route close to hide
        event.preventDefault() # this does nothing, contrary to the docs
        w.hide()
      w.on 'closed', (event) ->
        window.feedbackWindow = null # if the window does get closed, clear our ref to it

      url = path.join __dirname, '..', 'feedback.html'
      w.loadUrl("file://#{url}?#{params}")
      w.show()

module.exports = FeedbackButton
