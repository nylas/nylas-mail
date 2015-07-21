_ = require 'underscore'
React = require 'react'
{Actions, Utils, UpdateThreadsTask} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class StarButton extends React.Component
  @displayName: "StarButton"
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    selected = @props.thread? and @props.thread.starred
    <button className="btn btn-toolbar btn-star"
            data-tooltip="Star"
            onClick={@_onStarToggle}>
      <RetinaImg name="toolbar-star.png" mode={RetinaImg.Mode.ContentIsMask} selected={selected} />
    </button>

  _onStarToggle: (e) =>
    threads = [@props.thread]
    if @props.thread.starred
      values = starred: false
    else
      values = starred: true

    task = new UpdateThreadsTask(threads, values)
    Actions.queueTask(task)
    e.stopPropagation()


module.exports = StarButton
