React = require 'react'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class SendingCancelButton extends React.Component
  @displayName: 'SendingCancelButton'

  @propTypes:
    taskId: React.PropTypes.string.isRequired

  constructor: (@props) ->
    @state =
      cancelling: false

  render: =>
    if @state.cancelling
      <RetinaImg
        style={width: 20, height: 20, marginTop: 2}
        name="inline-loading-spinner.gif"
        mode={RetinaImg.Mode.ContentPreserve} />
    else
      <div onClick={@_onClick} style={marginTop: 1}>
        <RetinaImg
          name="image-cancel-button.png"
          mode={RetinaImg.Mode.ContentPreserve} />
      </div>

  _onClick: =>
    Actions.dequeueTask(@props.taskId)
    @setState(cancelling: true)

module.exports = SendingCancelButton
