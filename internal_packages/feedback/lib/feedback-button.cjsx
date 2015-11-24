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
    return if NylasEnv.inSpecMode()

    Screen = require('remote').require('screen')
    qs = require 'querystring'

    account = AccountStore.current()
    params = qs.stringify({
      name: account.name
      email: account.emailAddress
      accountId: account.id
      accountProvider: account.provider
      platform: process.platform
      provider: account.displayProvider()
      organizational_unit: account.organizationUnit
      version: NylasEnv.getVersion()
    })

    parentBounds = NylasEnv.getCurrentWindow().getBounds()
    parentScreen = Screen.getDisplayMatching(parentBounds)

    width = 376
    height = Math.min(550, parentBounds.height)
    x = Math.min(parentScreen.workAreaSize.width - width, Math.max(0, parentBounds.x + parentBounds.width - 36 - width / 2))
    y = Math.max(0, (parentBounds.y + parentBounds.height) - height - 60)

    require('electron').ipcRenderer.send('show-feedback-window', { x, y, width, height, params })
    setTimeout =>
      @setState(newMessages: false)
    , 250

module.exports = FeedbackButton
