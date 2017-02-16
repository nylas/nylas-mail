React = require 'react'
ReactDOM = require 'react-dom'
ReactCSSTransitionGroup = require 'react-addons-css-transition-group'
_ = require 'underscore'
classNames = require 'classnames'

SyncActivity = require("./sync-activity").default
SyncbackActivity = require("./syncback-activity").default

{Utils,
 Actions,
 TaskQueue,
 AccountStore,
 NylasSyncStatusStore,
 TaskQueueStatusStore
 PerformSendActionTask,
 SendDraftTask} = require 'nylas-exports'

SEND_TASK_CLASSES = [PerformSendActionTask, SendDraftTask]

class ActivitySidebar extends React.Component
  @displayName: 'ActivitySidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 400

  constructor: (@props) ->
    @state = @_getStateFromStores()

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidMount: =>
    @_unlisteners = []
    @_unlisteners.push TaskQueueStatusStore.listen @_onDataChanged
    @_unlisteners.push NylasSyncStatusStore.listen @_onDataChanged

  componentWillUnmount: =>
    unlisten() for unlisten in @_unlisteners

  render: =>
    sendTasks = []
    nonSendTasks = []
    @state.tasks.forEach (task) ->
      if SEND_TASK_CLASSES.some(((taskClass) -> task instanceof taskClass ))
        sendTasks.push(task)
      else
        nonSendTasks.push(task)


    names = classNames
      "sidebar-activity": true
      "sidebar-activity-error": error?

    wrapperClass = "sidebar-activity-transition-wrapper "

    inside = <ReactCSSTransitionGroup
      className={names}
      transitionLeaveTimeout={625}
      transitionEnterTimeout={125}
      transitionName="activity-opacity">
        <SyncbackActivity syncbackTasks={sendTasks} />
        <SyncActivity
          initialSync={!@state.isInitialSyncComplete}
          syncbackTasks={nonSendTasks}
        />
    </ReactCSSTransitionGroup>

    <ReactCSSTransitionGroup
      className={wrapperClass}
      transitionLeaveTimeout={625}
      transitionEnterTimeout={125}
      transitionName="activity-opacity">
        {inside}
    </ReactCSSTransitionGroup>

  _onDataChanged: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    tasks: TaskQueueStatusStore.queue()
    isInitialSyncComplete: NylasSyncStatusStore.isSyncComplete()

module.exports = ActivitySidebar
