_ = require 'underscore-plus'
{Actions, ThreadStore} = require 'inbox-exports'

module.exports =
ThreadListMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @thread_store_unsubscribe = ThreadStore.listen @_onChange
    @command_unsubscriber = atom.commands.add '.thread-list-container', {
      'thread-list:move-up': => @_onShiftSelectedIndex(-1)
      'thread-list:move-down': => @_onShiftSelectedIndex(1)
      'thread-list:archive-thread': @_onArchiveSelected
      'thread-list:reply': @_onReply
      'thread-list:reply-all': @_onReplyAll
      'thread-list:forward': @_onForward
    }

  componentWillUnmount: ->
    @thread_store_unsubscribe()
    @command_unsubscriber.dispose()

  _onShiftSelectedIndex: (delta) ->
    item = _.find @state.threads, (thread) => thread.id == @state?.selected
    index = if item then @state.threads.indexOf(item) else -1
    index = Math.max(0, Math.min(index + delta, @state.threads.length-1))
    Actions.selectThreadId(@state.threads[index].id)

  _onArchiveSelected: ->
    thread = ThreadStore.selectedThread()
    thread.archive() if thread

  _onReply: ->
    thread = ThreadStore.selectedThread()
    Actions.composeReply(thread.id) if thread?

  _onReplyAll: ->
    thread = ThreadStore.selectedThread()
    Actions.composeReplyAll(thread.id) if thread?

  _onForward: ->
    thread = ThreadStore.selectedThread()
    Actions.composeForward(thread.id) if thread?

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    count: ThreadStore.items().length
    threads: ThreadStore.items()
    selected: ThreadStore.selectedId()

