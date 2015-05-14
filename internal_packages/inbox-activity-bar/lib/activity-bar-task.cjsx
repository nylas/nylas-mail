React = require 'react/addons'
classNames = require 'classnames'
_ = require 'underscore-plus'
{Utils} = require 'inbox-exports'

class ActivityBarTask extends React.Component
  @displayName: 'ActivityBarTask'

  constructor: (@props) ->
    @state = expanded: false

  render: =>
    <div className={@_classNames()} onClick={=> @setState expanded: not @state.expanded}>
      <div className="task-summary">
        {@_taskSummary()}
      </div>
      <div className="task-details">
        {JSON.stringify(@props.task.toJSON())}
      </div>
    </div>

  shouldComponentUpdate: (nextProps, nextState) =>
    return not Utils.isEqualReact(nextProps, @props) or not Utils.isEqualReact(nextState, @state)

  _taskSummary: =>
    qs = @props.task.queueState
    errType = ""
    errCode = ""
    errMessage = ""
    if qs.localError?
      localError = qs.localError
      errType = localError.constructor.name
      errMessage = localError.message ? JSON.stringify(localError)
    else if qs.remoteError?
      remoteError = qs.remoteError
      errType = remoteError.constructor.name
      errCode = remoteError.statusCode ? ""
      errMessage = remoteError.body?.message ? remoteError?.message ? JSON.stringify(remoteError)

    return "#{@props.task.constructor.name} #{errType} #{errCode} #{errMessage}"

  _classNames: =>
    qs = @props.task.queueState ? {}
    classNames
      "task": true
      "task-queued": @props.type is "queued"
      "task-completed": @props.type is "completed"
      "task-expanded": @state.expanded
      "task-local-error": qs.localError
      "task-remote-error": qs.remoteError
      "task-is-processing": qs.isProcessing
      "task-success": qs.performedLocal and qs.performedRemote


module.exports = ActivityBarTask
