{Utils,
 React,
 FocusedContactsStore,
 AccountStore,
 Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class FeedbackButton extends React.Component
  @displayName: 'FeedbackButton'

  constructor: (@props) ->

  componentDidMount: =>
    @_unsubs = []
    @_unsubs.push Actions.sendFeedback.listen(@_onSendFeedback)

  componentWillUnmount: =>
    unsub() for unsub in @_unsubs

  render: =>
    <div style={position:"absolute",height:0} title="Help & Feedback">
      <div className="btn-feedback" onClick={@_onSendFeedback}>?</div>
    </div>

  _onSendFeedback: =>
    return if NylasEnv.inSpecMode()
    require('electron').shell.openExternal('http://support.nylas.com/')

module.exports = FeedbackButton
