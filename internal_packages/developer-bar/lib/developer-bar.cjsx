_ = require 'underscore'
React = require 'react/addons'
{DatabaseStore,
 NamespaceStore,
 TaskQueue,
 Actions,
 Contact,
 Message} = require 'nylas-exports'
{ResizableRegion} = require 'nylas-component-kit'

DeveloperBarStore = require './developer-bar-store'
DeveloperBarTask = require './developer-bar-task'
DeveloperBarCurlItem = require './developer-bar-curl-item'
DeveloperBarLongPollItem = require './developer-bar-long-poll-item'

DeveloperBarClosedHeight = 30

class DeveloperBar extends React.Component
  @displayName: "DeveloperBar"

  @containerRequired: false

  constructor: (@props) ->
    @state = _.extend @_getStateFromStores(),
      height: DeveloperBarClosedHeight
      section: 'curl'
      filter: ''

  componentDidMount: =>
    @taskQueueUnsubscribe = TaskQueue.listen @_onChange
    @activityStoreUnsubscribe = DeveloperBarStore.listen @_onChange

  componentWillUnmount: =>
    @taskQueueUnsubscribe() if @taskQueueUnsubscribe
    @activityStoreUnsubscribe() if @activityStoreUnsubscribe

  render: =>
    # TODO WARNING: This 1px height is necessary to fix a redraw issue in the thread
    # list in Chrome 42 (Electron 0.26.0). Do not remove unless you've verified that
    # scrolling works fine now and repaints aren't visible.
    return <div style={height:1}></div> unless @state.visible

    <ResizableRegion className="developer-bar"
                     initialHeight={@state.height}
                     minHeight={DeveloperBarClosedHeight}
                     handle={ResizableRegion.Handle.Top}>
      <div className="controls">
        {@_caret()}
        <div className="btn-container pull-left">
          <div className="btn" onClick={ => @_onExpandSection('queue')}>
            <span>Queue Length: {@state.queue?.length}</span>
          </div>
        </div>
        <div className="btn-container pull-left">
          <div className="btn" onClick={ => @_onExpandSection('long-polling')}>
            <div className={"activity-status-bubble state-" + @state.longPollState}></div>
            <span>Long Polling: {@state.longPollState}</span>
          </div>
        </div>
        <div className="btn-container pull-left">
          <div className="btn" onClick={ => @_onExpandSection('curl')}>
            <span>Requests: {@state.curlHistory.length}</span>
          </div>
        </div>
        <div className="btn-container pull-right">
          <div className="btn" onClick={Actions.sendFeedback}>Feedback</div>
        </div>
        <div className="btn-container pull-right">
          <div className="btn" onClick={@_onToggleRegions}>Component Regions</div>
        </div>
      </div>
      {@_sectionContent()}
      <div className="footer">
        <div className="btn" onClick={@_onClear}>Clear</div>
        <input className="filter" placeholder="Filter..." value={@state.filter} onChange={@_onFilter} />
      </div>
    </ResizableRegion>

  _caret: =>
    if @state.height > DeveloperBarClosedHeight
      <i className="fa fa-caret-square-o-down" onClick={@_onHide}></i>
    else
      <i className="fa fa-caret-square-o-up" onClick={@_onShow}></i>

  _sectionContent: =>
    expandedDiv = <div></div>

    matchingFilter = (item) =>
      return true if @state.filter is ''
      return JSON.stringify(item).indexOf(@state.filter) >= 0

    if @state.section == 'curl'
      itemDivs = @state.curlHistory.filter(matchingFilter).map (item) ->
        <DeveloperBarCurlItem item={item} key={item.id}/>
      expandedDiv = <div className="expanded-section curl-history">{itemDivs}</div>

    else if @state.section == 'long-polling'
      itemDivs = @state.longPollHistory.filter(matchingFilter).map (item) ->
        <DeveloperBarLongPollItem item={item} key={item.cursor}/>
      expandedDiv = <div className="expanded-section long-polling">{itemDivs}</div>

    else if @state.section == 'queue'
      queue = @state.queue.filter(matchingFilter)
      queueDivs = for i in [@state.queue.length - 1..0] by -1
        task = @state.queue[i]
        <DeveloperBarTask task={task}
                         key={task.id}
                         type="queued" />

      queueCompleted = @state.completed.filter(matchingFilter)
      queueCompletedDivs = for i in [@state.completed.length - 1..0] by -1
        task = @state.completed[i]
        <DeveloperBarTask task={task}
                         key={task.id}
                         type="completed" />

      expandedDiv =
        <div className="expanded-section queue">
          <div className="btn queue-buttons"
               onClick={@_onDequeueAll}>Remove Queued Tasks</div>
          <div className="section-content">
            {queueDivs}
            <hr />
            {queueCompletedDivs}
          </div>
        </div>

      expandedDiv

  _onChange: =>
    @setState(@_getStateFromStores())

  _onClear: =>
    Actions.clearDeveloperConsole()

  _onFilter: (ev) =>
    @setState(filter: ev.target.value)

  _onDequeueAll: =>
    Actions.dequeueAllTasks()

  _onHide: =>
    @setState
      height: DeveloperBarClosedHeight

  _onShow: =>
    @setState(height: 200) if @state.height < 100

  _onExpandSection: (section) =>
    @setState(section: section)
    @_onShow()

  _onToggleRegions: =>
    Actions.toggleComponentRegions()

  _getStateFromStores: =>
    visible: DeveloperBarStore.visible()
    queue: TaskQueue._queue
    completed: TaskQueue._completed
    curlHistory: DeveloperBarStore.curlHistory()
    longPollHistory: DeveloperBarStore.longPollHistory()
    longPollState: DeveloperBarStore.longPollState()


module.exports = DeveloperBar
