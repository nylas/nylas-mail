_ = require 'underscore-plus'
React = require 'react'

{ComponentRegistry} = require 'inbox-exports'

ThreadListMixin = require './thread-list-mixin.cjsx'
ThreadListColumn = require("./thread-list-column")
ThreadListTabularItem = require './thread-list-tabular-item.cjsx'

module.exports =
ThreadListTabular = React.createClass
  mixins: [ComponentRegistry.Mixin, ThreadListMixin]
  displayName: 'ThreadListTabular'
  components: ["Participants"]

  getInitialState: ->
    columns: @_defaultColumns()
    threadLabelComponents: ComponentRegistry.findAllByRole("thread label")

  componentWillUpdate: ->
    @_colFlex = null

  componentWillMount: ->
    @unlisteners = []
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState
        threadLabelComponents: ComponentRegistry.findAllByRole("thread label")

  componentWillUnmount: ->
    unlisten() for unlisten in @unlisteners

  render: ->
    <div tabIndex=1
         className="thread-list-container thread-list-tabular">

      <div className="thread-list-headers">
        {@_threadHeaders()}
      </div>

      <div className="thread-rows">
        {@_threadRows()}
      </div>
    </div>

  _defaultColumns: ->
    c1 = new ThreadListColumn
      name: "Name"
      flex: 2
      resolver: (thread, parentComponent) =>
        Participants = @state.Participants
        <Participants participants={thread.participants}
                      context={'list'} clickable={false} />

    subject = (thread) ->
      if (thread.subject ? "").trim().length is 0
        return <span className="no-subject">(No Subject)</span>
      else return thread.subject

    labelComponents = (thread) =>
      for label in @state.threadLabelComponents
        LabelComponent = label.view
        <LabelComponent thread={thread} />

    c2 = new ThreadListColumn
      name: "Subject"
      flex: 6
      resolver: (thread) ->
        <span>
          <span className="subject">{subject(thread)}</span>&nbsp;&nbsp;&nbsp;
          <span className="snippet">{thread.snippet}</span>
          {labelComponents(thread)}
        </span>

    c3 = new ThreadListColumn
      name: "Date"
      flex: 1
      resolver: (thread, parentComponent) -> parentComponent.threadTime()

    return [c1, c2, c3]

  _threadHeaders: ->
    for col in @state.columns
      <div className="thread-list-header thread-list-column"
           key={"header-#{col.name}"}
           style={flex: "#{@_columnFlex()[col.name]}"}>
        {col.name}
      </div>

  _threadRows: ->
    @state.threads.map (thread) =>
      <ThreadListTabularItem key={thread.id}
                             thread={thread}
                             columns={@state.columns}
                             unread={thread.isUnread()}
                             columnFlex={@_columnFlex()}
                             selected={thread?.id == @state.selected}/>

  _columnFlex: ->
    if @_colFlex? then return @_colFlex
    @_colFlex = {}
    for col in (@state.columns ? [])
      @_colFlex[col.name] = col.flex
    return @_colFlex
