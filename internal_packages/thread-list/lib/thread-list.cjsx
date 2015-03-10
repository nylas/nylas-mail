_ = require 'underscore-plus'
React = require 'react'
{ListTabular} = require 'ui-components'
{timestamp, subject} = require './formatting-utils'
{Actions, ThreadStore, ComponentRegistry} = require 'inbox-exports'

module.exports =
ThreadList = React.createClass
  displayName: 'ThreadList'

  mixins: [ComponentRegistry.Mixin]
  components: ['Participants']

  getInitialState: ->
    @_getStateFromStores()
 
  componentDidMount: ->
    @thread_store_unsubscribe = ThreadStore.listen @_onChange
    @thread_unsubscriber = atom.commands.add '.thread-list', {
      'thread-list:star-thread': => @_onStarThread()
    }
    @body_unsubscriber = atom.commands.add 'body', {
      'application:previous-item': => @_onShiftSelectedIndex(-1)
      'application:next-item': => @_onShiftSelectedIndex(1)
      'application:remove-item': @_onArchiveSelected
      'application:remove-and-previous': @_onArchiveAndPrevious
      'application:reply': @_onReply
      'application:reply-all': @_onReplyAll
      'application:forward': @_onForward
    }

  componentWillUnmount: ->
    @thread_store_unsubscribe()
    @thread_unsubscriber.dispose()
    @body_unsubscriber.dispose()

  render: ->
    <div className="thread-list">
      <ListTabular
        columns={@state.columns}
        items={@state.items}
        itemClassProvider={ (item) -> if item.isUnread() then 'unread' else '' }
        selectedId={@state.selectedId}
        onSelect={ (item) -> Actions.selectThreadId(item.id) } />
    </div>
    
  _computeColumns: ->
    labelComponents = (thread) =>
      for label in @state.threadLabelComponents
        LabelComponent = label.view
        <LabelComponent thread={thread} />

    numUnread = (thread) ->
      numMsg = thread.numUnread()
      if numMsg < 2
        <span></span>
      else
        <span className="message-count item-count-box">{numMsg}</span>

    c0 = new ListTabular.Column
      name: "★"
      flex: 0.2
      resolver: (thread) ->
        <span className="btn-icon star-button"
              onClick={ -> thread.toggleStar.apply(thread)}>
          <i className={"fa " + (thread.isStarred() and 'fa-star' or 'fa-star-o')}/>
        </span>

    c1 = new ListTabular.Column
      name: "Name"
      flex: 2
      resolver: (thread) =>
        Participants = @state.Participants
        <div className="participants">
          <Participants participants={thread.participants}
                        context={'list'} clickable={false} />
        </div>

    c2 = new ListTabular.Column
      name: "Subject"
      flex: 3
      resolver: (thread) ->
        <span className="subject">{subject(thread.subject)}</span>

    c3 = new ListTabular.Column
      name: "Snippet"
      flex: 4
      resolver: (thread) ->
        <span className="snippet">{thread.snippet}</span>

    c4 = new ListTabular.Column
      name: "Date"
      flex: 1
      resolver: (thread) ->
        <span className="timestamp">{timestamp(thread.lastMessageTimestamp)}</span>

    [c1, c2, c3, c4]

  _onShiftSelectedIndex: (delta) ->
    item = _.find @state.items, (thread) => thread.id == @state.selectedId
    index = if item then @state.items.indexOf(item) else -1
    index = Math.max(0, Math.min(index + delta, @state.items.length-1))
    Actions.selectThreadId(@state.items[index].id)

  _onArchiveSelected: ->
    thread = ThreadStore.selectedThread()
    thread.archive() if thread

  _onStarThread: ->
    thread = ThreadStore.selectedThread()
    thread.toggleStar() if thread

  _onReply: ->
    return unless @state.selectedId?
    Actions.composeReply(threadId: @state.selectedId)

  _onReplyAll: ->
    return unless @state.selectedId?
    Actions.composeReplyAll(threadId: @state.selectedId)

  _onForward: ->
    return unless @state.selectedId?
    Actions.composeForward(threadId: @state.selectedId)
    
  _onChange: ->
    @setState(@_getStateFromStores())

  _onArchiveAndPrevious: ->
    @_onArchiveSelected()
    @_onShiftSelectedIndex(-1)

  _getStateFromStores: ->
    items: ThreadStore.items()
    columns: @_computeColumns()
    selectedId: ThreadStore.selectedId()
