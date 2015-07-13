React = require 'react'
_ = require 'underscore'
classNames = require 'classnames'
NotificationStore = require './notifications-store'
{Actions,
 TaskQueue,
 NamespaceStore,
 NylasAPI} = require 'nylas-exports'
{TimeoutTransitionGroup} = require 'nylas-component-kit'

class ActivitySidebar extends React.Component
  @displayName: 'ActivitySidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 207

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unlisteners = []
    @_unlisteners.push NamespaceStore.listen @_onNamespacesChanged
    @_unlisteners.push TaskQueue.listen @_onDataChanged
    @_unlisteners.push NotificationStore.listen @_onDataChanged
    @_onNamespacesChanged()

  componentWillUnmount: =>
    unlisten() for unlisten in @_unlisteners
    @_workerUnlisten() if @_workerUnlisten

  render: =>
    items = [].concat(@_renderSyncActivityItem(), @_renderNotificationActivityItems(), @_renderTaskActivityItems())

    names = classNames
      "sidebar-activity": true
      "sidebar-activity-empty": items.length is 0
      "sidebar-activity-error": error?

    <TimeoutTransitionGroup
      className={names}
      leaveTimeout={625}
      enterTimeout={125}
      transitionName="activity-item">
      {items}
    </TimeoutTransitionGroup>

  _renderSyncActivityItem: =>
    count = 0
    fetched = 0
    progress = 0
    incomplete = 0
    error = null

    for model, modelState of @state.sync
      incomplete += 1 unless modelState.complete
      error ?= modelState.error
      if modelState.count
        count += modelState.count / 1
        fetched += modelState.fetched / 1

    progress = (fetched / count) * 100 if count > 0

    if incomplete is 0
      return []
    else if error
      <div className="item">
        <div className="inner">Initial sync encountered an error. Waiting to retry...
          <div className="btn btn-emphasis" onClick={@_onTryAgain}>Try Again</div>
        </div>
      </div>
    else
      <div className="item">
        <div className="progress-track">
          <div className="progress" style={width: "#{progress}%"}></div>
        </div>
        <div className="inner">Syncing mail data...</div>
      </div>

  _renderTaskActivityItems: =>
    summary = {}

    @state.tasks.map (task) ->
      label = task.label?()
      return unless label
      summary[label] ?= 0
      summary[label] += 1

    _.pairs(summary).map ([label, count]) ->
      <div className="item" key={label}>
        <div className="inner">
          {label} <span className="count">({count})</span>
        </div>
      </div>

  _renderNotificationActivityItems: =>
    @state.notifications.map (notification) ->
      <div className="item" key={notification.id}>
        <div className="inner">
          {notification.message}
        </div>
      </div>

  _onNamespacesChanged: =>
    namespace = NamespaceStore.current()
    return unless namespace
    @_worker = NylasAPI.workerForNamespace(namespace)
    @_workerUnlisten() if @_workerUnlisten
    @_workerUnlisten = @_worker.listen(@_onDataChanged, @)
    @_onDataChanged()

  _onTryAgain: =>
    @_worker.resumeFetches()

  _onDataChanged: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    tasks: TaskQueue.queue()
    notifications: NotificationStore.notifications()
    sync: @_worker?.state()


module.exports = ActivitySidebar
