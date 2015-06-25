_ = require 'underscore'
React = require 'react'
{Actions, Utils, AddRemoveTagsTask} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class StarButton extends React.Component
  @displayName: "StarButton"
  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    selected = @props.thread? and @props.thread.isStarred()
    <button className="btn btn-toolbar"
            data-tooltip="Star"
            onClick={@_onStarToggle}>
      <RetinaImg name="toolbar-star.png" mode={RetinaImg.Mode.ContentIsMask} selected={selected} />
    </button>

  _onStarToggle: (e) =>
    if @props.thread.isStarred()
      task = new AddRemoveTagsTask(@props.thread, [], ['starred'])
    else
      task = new AddRemoveTagsTask(@props.thread, ['starred'], [])

    Actions.queueTask(task)
    e.stopPropagation()


module.exports = StarButton
