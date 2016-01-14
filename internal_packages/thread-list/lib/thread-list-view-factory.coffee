Rx = require 'rx-lite'
{Thread,
 Message,
 AccountStore,
 DatabaseStore,
 QuerySubscription,
 QueryResultSet,
 ObservableListDataSource,
 MutableQuerySubscription} = require 'nylas-exports'

PaginatingSearch = require './paginating-search'

_flatMapJoiningMessages = ($threadsResultSet) =>
  # DatabaseView leverages `QuerySubscription` for threads /and/ for the
  # messages on each thread, which are passed to out as `thread.metadata`.

  $messagesResultSets = {}

  # 2. when we receive a set of threads, we check to see if we have message
  #    observables for each thread. If threads have been added to the result set,
  #    we make a single database query and load /all/ the message metadata for
  #    the new threads at once. (This is a performance optimization -it's about
  #    ~80msec faster than making 100 queries for 100 new thread ids separately.)
  Rx.Observable.zip([
    $threadsResultSet,
    $threadsResultSet.flatMapLatest (threadsResultSet) =>
      missingIds = threadsResultSet.ids().filter (id) -> not $messagesResultSets[id]
      return Rx.Observable.from([[]]) if missingIds.length is 0
      Rx.Observable.fromPromise(DatabaseStore.findAll(Message, threadId: missingIds))
  ])

  # 3. when that finishes, we group the loaded messsages by threadId and create
  #    the missing observables. Creating a query subscription would normally load
  #    an initial result set. To avoid that, we just hand new subscriptions the
  #    results we loaded in #2.
  .flatMapLatest ([threadsResultSet, messagesForNewThreads]) =>
    messagesGrouped = {}
    for message in messagesForNewThreads
      messagesGrouped[message.threadId] ?= []
      messagesGrouped[message.threadId].push(message)

    oldSets = $messagesResultSets
    $messagesResultSets = {}

    sets = threadsResultSet.ids().map (id) =>
      $messagesResultSets[id] = oldSets[id] || _observableForThreadMessages(id, messagesGrouped[id])
      $messagesResultSets[id]
    sets.unshift(Rx.Observable.from([threadsResultSet]))

    # 4. We use `combineLatest` to merge the message observables into a single
    #    stream (like Promise.all).  When /any/ of them emit a new result set, we
    #    trigger.
    Rx.Observable.combineLatest(sets)

  .flatMapLatest ([threadsResultSet, messagesResultSets...]) =>
    threadsWithMetadata = {}
    threadsResultSet.models().map (thread, idx) ->
      thread = new thread.constructor(thread)
      thread.metadata = messagesResultSets[idx]?.models()
      threadsWithMetadata[thread.id] = thread

    Rx.Observable.from([QueryResultSet.setByApplyingModels(threadsResultSet, threadsWithMetadata)])

_observableForThreadMessages = (id, initialModels) ->
  subscription = new QuerySubscription(DatabaseStore.findAll(Message, threadId: id), {
    asResultSet: true,
    initialModels: initialModels
  })
  Rx.Observable.fromPrivateQuerySubscription('message-'+id, subscription)


module.exports = ThreadListViewFactory =
  viewForPerspective: (mailboxPerspective) =>
    if mailboxPerspective.searchQuery
      ThreadListViewFactory.viewForSearch(mailboxPerspective.searchQuery, mailboxPerspective.account?.id)
    else
      matchers = []
      if mailboxPerspective.account
        matchers.push Thread.attributes.accountId.equal(mailboxPerspective.account.id)
      matchers = matchers.concat(mailboxPerspective.matchers())
      query = DatabaseStore.findAll(Thread).where(matchers).limit(0)
      ThreadListViewFactory.viewForQuery(query)

  viewForSearch: (terms, accountId) =>
    search = new PaginatingSearch(terms, accountId)
    $resultSet = _flatMapJoiningMessages(search.observable())

    return new ObservableListDataSource $resultSet, ({start, end}) =>
      search.setRange({start, end})

  viewForQuery: (query) =>
    subscription = new MutableQuerySubscription(query, {asResultSet: true})
    $resultSet = Rx.Observable.fromPrivateQuerySubscription('thread-list', subscription)
    $resultSet = _flatMapJoiningMessages($resultSet)

    return new ObservableListDataSource $resultSet, ({start, end}) =>
      subscription.replaceQuery(query.clone().page(start, end))
