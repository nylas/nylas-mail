React = require 'react'
ReactDOM = require 'react-dom'
ReactCSSTransitionGroup = require 'react-addons-css-transition-group'
_ = require 'underscore'
classNames = require 'classnames'

NotificationStore = require '../notifications-store'
StreamingSyncActivity = require './streaming-sync-activity'
InitialSyncActivity = require './initial-sync-activity'

{Actions,
 TaskQueue,
 AccountStore,
 NylasSyncStatusStore,
 TaskQueueStatusStore} = require 'nylas-exports'

class ActivitySidebar extends React.Component
  @displayName: 'ActivitySidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 400

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unlisteners = []
    @_unlisteners.push TaskQueueStatusStore.listen @_onDataChanged
    @_unlisteners.push NotificationStore.listen @_onDataChanged
    @_unlisteners.push NylasSyncStatusStore.listen @_onDataChanged

  componentWillUnmount: =>
    unlisten() for unlisten in @_unlisteners

  render: =>
    items = [@_renderNotificationActivityItems(), @_renderTaskActivityItems()]

    if @state.isInitialSyncComplete
      items.push <StreamingSyncActivity key="streaming-sync" />
    else
      items.push <InitialSyncActivity key="initial-sync" />

    names = classNames
      "sidebar-activity": true
      "sidebar-activity-error": error?

    wrapperClass = "sidebar-activity-transition-wrapper "

    if items.length is 0
      wrapperClass += "sidebar-activity-empty"
    else
      inside = <ReactCSSTransitionGroup
        className={names}
        transitionLeaveTimeout={625}
        transitionEnterTimeout={125}
        transitionName="activity-opacity">
        {items}
      </ReactCSSTransitionGroup>

    <ReactCSSTransitionGroup
      className={wrapperClass}
      transitionLeaveTimeout={625}
      transitionEnterTimeout={125}
      transitionName="activity-opacity">
        {inside}
    </ReactCSSTransitionGroup>

  _renderTaskActivityItems: =>
    summary = {}

    @state.tasks.map (task) ->
      label = task.label?()
      return unless label
      summary[label] ?= 0
      summary[label] += task.numberOfImpactedItems()

    _.pairs(summary).map ([label, count]) ->
      <div className="item" key={label}>
        <div className="inner">
          <span className="count">({new Number(count).toLocaleString()})</span>
          {label}
        </div>
      </div>

  _renderNotificationActivityItems: =>
    @state.notifications.map (notification) ->
      <div className="item" key={notification.id}>
        <div className="inner">
          {notification.message}
        </div>
      </div>

  _onDataChanged: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    notifications: NotificationStore.notifications()
    tasks: TaskQueueStatusStore.queue()
    isInitialSyncComplete: NylasSyncStatusStore.isSyncComplete()

module.exports = ActivitySidebar
