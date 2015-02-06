React = require 'react'
{DatabaseStore,
 NamespaceStore,
 TaskStore,
 Actions,
 Contact,
 Message} = require 'inbox-exports'
ActivityBarStore = require './activity-bar-store'

ActivityBarCurlItem = React.createClass
  render: ->
    <div className={"item status-code-#{@props.item.statusCode}"}>
      <div className="code">{@props.item.statusCode}</div>
      <a onClick={@_onRunCommand}>Run</a>
      <a onClick={@_onCopyCommand}>Copy</a>
      {@props.item.command}
    </div>

  _onCopyCommand: ->
    clipboard = require('clipboard')
    clipboard.writeText(@props.item.command)

  _onRunCommand: ->
    curlFile = "#{atom.getConfigDirPath()}/curl.command"
    fs = require 'fs-plus'
    if fs.existsSync(curlFile)
      fs.unlinkSync(curlFile)
    fs.writeFileSync(curlFile, @props.item.command)
    fs.chmodSync(curlFile, '777')
    shell = require 'shell'
    shell.openItem(curlFile)


module.exports =
ActivityBar = React.createClass

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @task_store_unsubscribe = TaskStore.listen @_onChange
    @activity_store_unsubscribe = ActivityBarStore.listen @_onChange

  componentWillUnmount: ->
    @task_store_unsubscribe() if @task_store_unsubscribe
    @activity_store_unsubscribe() if @activity_store_unsubscribe

  render: ->
    expandedDiv = <div></div>

    if @state.expandedSection == 'curl'
      curlDivs = @state.curlHistory.map (item) ->
        <ActivityBarCurlItem item={item}/>
      expandedDiv = <div className="expanded-section curl-history">{curlDivs}</div>

    if @state.expandedSection == 'queue'
      queueDivs = @state.queuePending.map (task) ->
        <div className="item item-pending">
          <strong>{task.constructor.name}:</strong> {JSON.stringify(task.toJSON())}
        </div>
      queuePendingDivs = @state.queue.map (task) ->
        <div className="item">
          <strong>{task.constructor.name}:</strong> {JSON.stringify(task.toJSON())}
        </div>
      expandedDiv = <div className="expanded-section queue">
        <div className="btn" onClick={@_onResetQueue}>Reset Queue</div>
        <div className="btn" onClick={@_onRestartQueue}>Restart Queue</div>
        {queueDivs}{queuePendingDivs}</div>

    <div>
      <i className="fa fa-caret-square-o-down" onClick={@_onCloseSection}></i>
      <div className="queue-status">
        <div className="btn" onClick={@_onExpandQueueSection}>
          <div className={"activity-status-bubble state-" + @state.queueState}></div>
          <span>Queue Length: {@state.queue?.length + @state.queuePending?.length}</span>
        </div>
      </div>
      <div className="long-poll-status">
        <div className="btn">
          <div className={"activity-status-bubble state-" + @state.longPollState}></div>
          <span>Long Polling: {@state.longPollState}</span>
        </div>
      </div>
      <div className="curl-status">
        <div className="btn" onClick={@_onExpandCurlSection}>
          <span>Requests: {@state.curlHistory.length}</span>
        </div>
      </div>
      <div className="feedback">
        <div className="btn" onClick={@_onFeedback}>
          <span>Feedback</span>
        </div>
      </div>
      {expandedDiv}
    </div>

  _onChange: ->
    @setState(@_getStateFromStores())

  _onRestartQueue: ->
    Actions.restartTaskQueue()

  _onResetQueue: ->
    Actions.resetTaskQueue()

  _onCloseSection: ->
    Actions.developerPanelSelectSection('')

  _onExpandCurlSection: ->
    Actions.developerPanelSelectSection('curl')

  _onExpandQueueSection: ->
    Actions.developerPanelSelectSection('queue')

  _onFeedback: ->
    user = NamespaceStore.current().name
    debugData = JSON.stringify({
      queries: @state.curlHistory,
      queue: @state.queue,
      queue_pending: @state.queuePending
    }, null, '\t')
    draft = new Message
      from: [NamespaceStore.current().me()]
      to: [
        new Contact
          name: "Nilas Team"
          email: "feedback@nilas.com"
      ]
      date: (new Date)
      draft: true
      subject: "Feedback"
      namespaceId: NamespaceStore.current().id
      body: """
        <p>Hi, Edgehill team!</p>
        <p>I have some feedback for you.</p>
        <p><b>What happened</b><br/><br/></p>
        <p><b>Impact</b><br/><br/></p>
        <p><b>Feedback</b><br/><br/></p>
        <p><b>Environment</b><br/>I'm using Edgehill #{atom.getVersion()} and my platform is #{process.platform}-#{process.arch}.</p>
        <p>--</p>
        <p>#{user}</p><br>
        <p>-- Extra Debugging Data --</p>
        <p>#{debugData}</p>
      """
    DatabaseStore.persistModel(draft).then ->
      DatabaseStore.localIdForModel(draft).then (localId) ->
        Actions.composePopoutDraft(localId)

  _getStateFromStores: ->
    expandedSection: ActivityBarStore.expandedSection()
    curlHistory: ActivityBarStore.curlHistory()
    queue:TaskStore.queuedTasks()
    queuePending: TaskStore.pendingTasks()
    queueState: if TaskStore.isPaused() then "paused" else "running"
    longPollState: ActivityBarStore.longPollState()
