_ = require 'underscore'
React = require 'react'
{Actions, Utils, ChangeStarredTask} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class StarButton extends React.Component
  @displayName: "StarButton"
  @containerRequired: false
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    selected = @props.thread? and @props.thread.starred
    <button className="btn btn-toolbar"
            style={order: -104}
            title={if selected then "Remove star" else "Add star"}
            onClick={@_onStarToggle}>
      <RetinaImg name="toolbar-star.png" mode={RetinaImg.Mode.ContentIsMask} selected={selected} />
    </button>

  _onStarToggle: (e) =>
    task = new ChangeStarredTask({
      thread: @props.thread
      starred: !@props.thread.starred
    })
    Actions.queueTask(task)
    e.stopPropagation()


module.exports = StarButton
