_ = require 'underscore-plus'
{Actions, ThreadStore} = require 'inbox-exports'

module.exports =
ThreadListMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @thread_store_unsubscribe = ThreadStore.listen @_onChange
    @thread_unsubscriber = atom.commands.add '.thread-list-container', {
      'thread-list:star-thread': => @_onStarThread()
    }
    @body_unsubscriber = atom.commands.add 'body', {
      'application:previous-message': => @_onShiftSelectedIndex(-1)
      'application:next-message': => @_onShiftSelectedIndex(1)
      'application:archive-thread': @_onArchiveSelected
      'application:archive-and-previous': @_onArchiveAndPrevious
      'application:reply': @_onReply
      'application:reply-all': @_onReplyAll
      'application:forward': @_onForward
    }

  componentWillUnmount: ->
    @thread_store_unsubscribe()
    @thread_unsubscriber.dispose()
    @body_unsubscriber.dispose()

  _onShiftSelectedIndex: (delta) ->
    item = _.find @state.threads, (thread) => thread.id == @state?.selected
    index = if item then @state.threads.indexOf(item) else -1
    index = Math.max(0, Math.min(index + delta, @state.threads.length-1))
    Actions.selectThreadId(@state.threads[index].id)

  _onArchiveSelected: ->
    thread = ThreadStore.selectedThread()
    thread.archive() if thread

  _onStarThread: ->
    thread = ThreadStore.selectedThread()
    thread.toggleStar() if thread

  _onReply: ->
    thread = ThreadStore.selectedThread()
    Actions.composeReply(threadId: thread.id) if thread?

  _onReplyAll: ->
    thread = ThreadStore.selectedThread()
    Actions.composeReplyAll(threadId: thread.id) if thread?

  _onForward: ->
    thread = ThreadStore.selectedThread()
    Actions.composeForward(threadId: thread.id) if thread?

  _onChange: ->
    @setState(@_getStateFromStores())

  _onArchiveAndPrevious: ->
    @_onArchiveSelected()
    @_onShiftSelectedIndex(-1)

  _getStateFromStores: ->
    count: ThreadStore.items().length
    threads: ThreadStore.items()
    selected: ThreadStore.selectedId()

