_ = require 'underscore'
React = require 'react/addons'
{DatabaseStore,
 AccountStore,
 TaskQueue,
 Actions,
 Contact,
 Message} = require 'nylas-exports'

DeveloperBarStore = require './developer-bar-store'
DeveloperBarTask = require './developer-bar-task'
DeveloperBarCurlItem = require './developer-bar-curl-item'
DeveloperBarLongPollItem = require './developer-bar-long-poll-item'


class DeveloperBar extends React.Component
  @displayName: "DeveloperBar"

  @containerRequired: false

  constructor: (@props) ->
    @state = _.extend @_getStateFromStores(),
      section: 'curl'
      filter: ''

  componentDidMount: =>
    @taskQueueUnsubscribe = TaskQueue.listen @_onChange
    @activityStoreUnsubscribe = DeveloperBarStore.listen @_onChange

  componentWillUnmount: =>
    @taskQueueUnsubscribe() if @taskQueueUnsubscribe
    @activityStoreUnsubscribe() if @activityStoreUnsubscribe

  render: =>
    <div className="developer-bar">
      <div className="controls">
        <div className="btn-container pull-left">
          <div className="btn" onClick={ => @_onExpandSection('queue')}>
            <span>Queue Length: {@state.queue?.length}</span>
          </div>
        </div>
        <div className="btn-container pull-left">
          <div className="btn" onClick={ => @_onExpandSection('long-polling')}>
            { _.map @state.longPollState, (val, key) =>
              <div title={"Account ID #{key} - State: #{val}"} key={key} className={"activity-status-bubble state-" + val}></div>
            }
            <span>Long Polling</span>
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
      </div>
      {@_sectionContent()}
      <div className="footer">
        <div className="btn" onClick={@_onClear}>Clear</div>
        <input className="filter" placeholder="Filter..." value={@state.filter} onChange={@_onFilter} />
      </div>
    </div>

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

  _onExpandSection: (section) =>
    @setState(@_getStateFromStores())
    @setState(section: section)

  _getStateFromStores: =>
    queue: TaskQueue._queue
    completed: TaskQueue._completed
    curlHistory: DeveloperBarStore.curlHistory()
    longPollHistory: DeveloperBarStore.longPollHistory()
    longPollState: DeveloperBarStore.longPollState()


module.exports = DeveloperBar
