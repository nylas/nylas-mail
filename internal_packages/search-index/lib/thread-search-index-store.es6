import _ from 'underscore'
import {
  Utils,
  Thread,
  AccountStore,
  DatabaseStore,
} from 'nylas-exports'

const MAX_INDEX_SIZE = 100000
const CHUNKS_PER_ACCOUNT = 10
const INDEXING_WAIT = 1000
const MESSAGE_BODY_LENGTH = 50000
const INDEX_VERSION = 2

class ThreadSearchIndexStore {

  constructor() {
    this.unsubscribers = []
    this.indexer = null;
  }

  activate(indexer) {
    this.indexer = indexer;
    this.indexer.registerSearchableModel({
      modelClass: Thread,
      indexSize: MAX_INDEX_SIZE,
      indexCallback: (model) => this.updateThreadIndex(model),
      unindexCallback: (model) => this.unindexThread(model),
    });

    const date = Date.now();
    console.log('Thread Search: Initializing thread search index...')

    this.accountIds = _.pluck(AccountStore.accounts(), 'id')
    this.initializeIndex()
    .then(() => {
      NylasEnv.config.set('threadSearchIndexVersion', INDEX_VERSION)
      return Promise.resolve()
    })
    .then(() => {
      console.log(`Thread Search: Index built successfully in ${((Date.now() - date) / 1000)}s`)
      this.unsubscribers = [
        AccountStore.listen(this.onAccountsChanged),
        DatabaseStore.listen(this.onDataChanged),
      ]
    })
  }

  _isInvalidSize(size) {
    return !size || size > MAX_INDEX_SIZE || size === 0;
  }

  /**
   * We only want to build the entire index if:
   * - It doesn't exist yet
   * - It is too big
   * - We bumped the index version
   *
   * Otherwise, we just want to index accounts that haven't been indexed yet.
   * An account may not have been indexed if it is added and the app is closed
   * before sync completes
   */
  initializeIndex() {
    if (NylasEnv.config.get('threadSearchIndexVersion') !== INDEX_VERSION) {
      return this.clearIndex()
      .then(() => this.buildIndex(this.accountIds))
    }

    return DatabaseStore.searchIndexSize(Thread)
    .then((size) => {
      console.log(`Thread Search: Current index size is ${(size || 0)} threads`)
      if (this._isInvalidSize(size)) {
        return this.clearIndex().thenReturn(this.accountIds)
      }
      return this.getUnindexedAccounts()
    })
    .then((accountIds) => this.buildIndex(accountIds))
  }

  /**
   * When accounts change, we are only interested in knowing if an account has
   * been added or removed
   *
   * - If an account has been added, we want to index its threads, but wait
   *   until that account has been successfully synced
   *
   * - If an account has been removed, we want to remove its threads from the
   *   index
   *
   * If the application is closed before sync is completed, the new account will
   * be indexed via `initializeIndex`
   */
  onAccountsChanged = () => {
    _.defer(() => {
      const latestIds = _.pluck(AccountStore.accounts(), 'id')
      if (_.isEqual(this.accountIds, latestIds)) {
        return;
      }
      const date = Date.now()
      console.log(`Thread Search: Updating thread search index for accounts ${latestIds}`)

      const newIds = _.difference(latestIds, this.accountIds)
      const removedIds = _.difference(this.accountIds, latestIds)
      const promises = []
      if (newIds.length > 0) {
        promises.push(this.buildIndex(newIds))
      }

      if (removedIds.length > 0) {
        promises.push(
          Promise.all(removedIds.map(id => DatabaseStore.unindexModelsForAccount(id, Thread)))
        )
      }
      this.accountIds = latestIds
      Promise.all(promises)
      .then(() => {
        console.log(`Thread Search: Index updated successfully in ${((Date.now() - date) / 1000)}s`)
      })
    })
  }

  /**
   * When a thread gets updated we will update the search index with the data
   * from that thread if the account it belongs to is not being currently
   * synced.
   *
   * When the account is successfully synced, its threads will be added to the
   * index either via `onAccountsChanged` or via `initializeIndex` when the app
   * starts
   */
  onDataChanged = (change) => {
    if (change.objectClass !== Thread.name) {
      return;
    }
    _.defer(() => {
      const {objects, type} = change
      const threads = objects;

      let promises = []
      if (type === 'persist') {
        this.indexer.notifyHasIndexingToDo();
      } else if (type === 'unpersist') {
        promises = threads.map(thread => this.unindexThread(thread,
                                                  {isBeingUnpersisted: true}))
      }
      Promise.all(promises)
    })
  }

  buildIndex = (accountIds) => {
    if (!accountIds || accountIds.length === 0) { return Promise.resolve() }
    this.indexer.notifyHasIndexingToDo();
  }

  clearIndex() {
    return (
      DatabaseStore.dropSearchIndex(Thread)
      .then(() => DatabaseStore.createSearchIndex(Thread))
    )
  }

  getUnindexedAccounts() {
    return Promise.resolve(this.accountIds)
    .filter((accId) => DatabaseStore.isIndexEmptyForAccount(accId, Thread))
  }

  indexThread = (thread) => {
    return (
      this.getIndexData(thread)
      .then((indexData) => (
        DatabaseStore.indexModel(thread, indexData)
      ))
    )
  }

  updateThreadIndex = (thread) => {
    return (
      this.getIndexData(thread)
      .then((indexData) => (
        DatabaseStore.updateModelIndex(thread, indexData)
      ))
    )
  }

  unindexThread = (thread, opts) => {
    return DatabaseStore.unindexModel(thread, opts)
  }

  getIndexData(thread) {
    return thread.messages().then((messages) => {
      return {
        bodies: messages
           .map(({body, snippet}) => (!_.isString(body) ? {snippet} : {body}))
           .map(({body, snippet}) => (
             snippet || Utils.extractTextFromHtml(body, {maxLength: MESSAGE_BODY_LENGTH}).replace(/(\s)+/g, ' ')
           )).join(' '),
        to: messages.map(({to, cc, bcc}) => (
          _.uniq(to.concat(cc).concat(bcc).map(({name, email}) => `${name} ${email}`))
        )).join(' '),
        from: messages.map(({from}) => (
          from.map(({name, email}) => `${name} ${email}`)
        )).join(' '),
      };
    }).then(({bodies, to, from}) => {
      const categories = (
        thread.categories
        .map(({displayName}) => displayName)
        .join(' ')
      )

      return {
        categories: categories,
        to_: to,
        from_: from,
        body: bodies,
        subject: thread.subject,
      };
    });
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }
}

export default new ThreadSearchIndexStore()
