{Actions, React} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class StreamingSyncActivity extends React.Component

  constructor: (@props) ->
    @_timeoutId = null
    @state =
      receivingDelta: false

  componentDidMount: =>
    @_unlistener = Actions.longPollReceivedRawDeltasPing.listen(@_onDeltaReceived)

  componentWillUnmount: =>
    @_unlistener() if @_unlistener
    clearTimeout(@_timeoutId) if @_timeoutId

  render: =>
    return false unless @state.receivingDelta
    <div className="item" key="delta-sync-item">
      <div style={padding: "9px 9px 0 12px", float: "left"}>
        <RetinaImg name="sending-spinner.gif" width={18} mode={RetinaImg.Mode.ContentPreserve} />
      </div>
      <div className="inner">
        Syncing your mailbox&hellip;
      </div>
    </div>

  _onDeltaReceived: (countDeltas) =>
    tooSmallForNotification = countDeltas <= 10
    return if tooSmallForNotification

    if @_timeoutId
      clearTimeout(@_timeoutId)

    @_timeoutId = setTimeout(( =>
      delete(@_timeoutId)
      @setState(receivingDelta: false)
    ), 20000)

    @setState(receivingDelta: true)


module.exports = StreamingSyncActivity
