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
    c0 = new ThreadListColumn
      name: "★"
      flex: 0.2
      resolver: (thread, parentComponent) ->
        <span className="btn-icon star-button"
              onClick={ -> thread.toggleStar.apply(thread)}>
          <i className={"fa " + (thread.isStarred() and 'fa-star' or 'fa-star-o')}/>
        </span>

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

    return [c0, c1, c2, c3]

  _threadHeaders: ->
    for col in @state.columns
      <div className="thread-list-header thread-list-column"
           key={"header-#{col.name}"}
           style={flex: "#{@_columnFlex()[col.name]}"}>
        {col.name}
      </div>

  # The `numTags` attribute is only used to trigger a re-render of the
  # ThreadListTabularItem when a tag gets added or removed (like a star).
  # React's diffing engine does not detect the change the array nested
  # deep inside of the thread and does not call render on the associated
  # ThreadListTabularItem. Add the attribute fixes this.
  _threadRows: ->
    @state.threads.map (thread) =>
      <ThreadListTabularItem key={thread.id}
                             thread={thread}
                             numTags={thread.tags.length}
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
