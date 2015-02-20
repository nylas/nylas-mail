_ = require 'underscore-plus'
React = require 'react/addons'
{ComponentRegistry,
 DatabaseStore,
 NamespaceStore,
 TaskQueue,
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

ActivityBarTask = React.createClass
  render: ->
    <div className={@_classNames()} onClick={=> @setState expanded: not @state?.expanded}>
      <div className="task-summary">
        {@_taskSummary()}
      </div>
      <div className="task-details">
        {JSON.stringify(@props.task.toJSON())}
      </div>
    </div>

  _taskSummary: ->
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

  _classNames: ->
    qs = @props.task.queueState ? {}
    React.addons.classSet
      "task": true
      "task-queued": @props.type is "queued"
      "task-completed": @props.type is "completed"
      "task-expanded": @state?.expanded
      "task-local-error": qs.localError
      "task-remote-error": qs.remoteError
      "task-is-processing": qs.isProcessing
      "task-success": qs.performedLocal and qs.performedRemote

module.exports =
ActivityBar = React.createClass

  getInitialState: ->
    _.extend @_getStateFromStores(),
      open: false

  componentDidMount: ->
    @taskQueueUnsubscribe = TaskQueue.listen @_onChange
    @activityStoreUnsubscribe = ActivityBarStore.listen @_onChange
    @registryUnlisten = ComponentRegistry.listen @_onChange

  componentWillUnmount: ->
    @taskQueueUnsubscribe() if @taskQueueUnsubscribe
    @activityStoreUnsubscribe() if @activityStoreUnsubscribe
    @registryUnlisten() if @registryUnlisten

  render: ->
    if @state?.ResizableComponent?
      ResizableComponent = @state.ResizableComponent
    else
      ResizableComponent = React.createClass(render: -> <div>{@props.children}</div>)
    expandedDiv = <div></div>

    if @state.expandedSection == 'curl'
      curlDivs = @state.curlHistory.map (item) ->
        <ActivityBarCurlItem item={item}/>
      expandedDiv = <div className="expanded-section curl-history">{curlDivs}</div>

    if @state.expandedSection == 'queue'
      queueDivs = for i in [@state.queue.length - 1..0] by -1
        task = @state.queue[i]
        <ActivityBarTask task=task
                         key=task.id
                         type="queued" />

      queueCompletedDivs = for i in [@state.completed.length - 1..0] by -1
        task = @state.completed[i]
        <ActivityBarTask task=task
                         key=task.id
                         type="completed" />

      expandedDiv =
        <div className="expanded-section queue">
          <div className="btn queue-buttons"
               onClick={@_onClearQueue}>Clear Queue</div>
          <div className="section-content">
            {queueDivs}
            <hr />
            {queueCompletedDivs}
          </div>
        </div>

    <div>
      <div className="controls">
        {@_caret()}
        <div className="queue-status">
          <div className="btn" onClick={@_onExpandQueueSection}>
            <span>Queue Length: {@state.queue?.length}</span>
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
      </div>
      <div className={@_expandedPanelClass()}>
        <ResizableComponent initialHeight=200 >
          {expandedDiv}
        </ResizableComponent>
      </div>
    </div>

  _expandedPanelClass: ->
    React.addons.classSet
      "message-area": true
      "panel-open": @state.open

  _caret: ->
    if @state.open
      <i className="fa fa-caret-square-o-down" onClick={@_onHide}></i>
    else
      <i className="fa fa-caret-square-o-up" onClick={@_onShow}></i>

  _onChange: ->
    @setState(@_getStateFromStores())

  _onClearQueue: ->
    Actions.clearQueue()

  _onHide: -> @setState open: false
  _onShow: -> @setState open: true

  _onExpandCurlSection: ->
    @setState open: true
    Actions.developerPanelSelectSection('curl')

  _onExpandQueueSection: ->
    @setState open: true
    Actions.developerPanelSelectSection('queue')

  _onFeedback: ->
    user = NamespaceStore.current().name

    debugData = JSON.stringify({
      queries: @state.curlHistory,
      queue: @state.queue,
      completed: @state.completed
    }, null, '\t')

    # Remove API tokens from URLs included in the debug data
    # This regex detects ://user:pass@ and removes it.
    debugData = debugData.replace(/:\/\/(\w)*:(\w)?@/g, '://')

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
    ResizableComponent: ComponentRegistry.findViewByName 'ResizableComponent'
    expandedSection: ActivityBarStore.expandedSection()
    curlHistory: ActivityBarStore.curlHistory()
    queue: TaskQueue._queue
    completed: TaskQueue._completed
    longPollState: ActivityBarStore.longPollState()
