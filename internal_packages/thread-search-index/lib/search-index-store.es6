import _ from 'underscore'
import {
  Utils,
  Thread,
  AccountStore,
  DatabaseStore,
  NylasSyncStatusStore,
  QuotedHTMLTransformer,
} from 'nylas-exports'

const INDEX_SIZE = 10000
const MAX_INDEX_SIZE = 25000
const CHUNKS_PER_ACCOUNT = 10
const INDEXING_WAIT = 1000
const MESSAGE_BODY_LENGTH = 50000


class SearchIndexStore {

  constructor() {
    this.accountIds = _.pluck(AccountStore.accounts(), 'id')
    this.unsubscribers = []
  }

  activate() {
    NylasSyncStatusStore.whenSyncComplete().then(() => {
      const date = Date.now()
      console.log('ThreadSearch: Initializing thread search index...')
      this.initializeIndex(this.accountIds)
      .then(() => {
        console.log('ThreadSearch: Index built successfully in ' + ((Date.now() - date) / 1000) + 's')
        this.unsubscribers = [
          DatabaseStore.listen(::this.onDataChanged),
          AccountStore.listen(::this.onAccountsChanged),
        ]
      })
    })
  }

  initializeIndex(accountIds) {
    return DatabaseStore.searchIndexSize(Thread)
    .then((size) => {
      console.log('ThreadSearch: Current index size is ' + (size || 0) + ' threads')
      if (!size || size >= MAX_INDEX_SIZE || size === 0) {
        return this.clearIndex().thenReturn(true)
      }
      return Promise.resolve(false)
    })
    .then((shouldRebuild) => {
      if (shouldRebuild) {
        return this.buildIndex(accountIds)
      }
      return Promise.resolve()
    })
  }

  onAccountsChanged() {
    const date = Date.now()
    const newIds = _.pluck(AccountStore.accounts(), 'id')
    if (newIds.length === this.accountIds.length) {
      return;
    }

    this.accountIds = newIds
    this.clearIndex()
    .then(() => this.buildIndex(this.accountIds))
    .then(() => {
      console.log('ThreadSearch: Index rebuilt successfully in ' + ((Date.now() - date) / 1000) + 's')
    })
  }

  onDataChanged(change) {
    if (change.objectClass !== Thread.name) {
      return;
    }
    const {objects, type} = change
    let promises = []
    if (type === 'persist') {
      promises = objects.map(thread => this.updateThreadIndex(thread))
    } else if (type === 'unpersist') {
      promises = objects.map(thread => DatabaseStore.unindexModel(thread))
    }
    Promise.all(promises)
  }

  clearIndex() {
    return (
      DatabaseStore.dropSearchIndex(Thread)
      .then(() => DatabaseStore.createSearchIndex(Thread))
    )
  }

  buildIndex(accountIds) {
    const numAccounts = accountIds.length
    return Promise.resolve(accountIds)
    .each((accountId) => (
      this.indexThreadsForAccount(accountId, Math.floor(INDEX_SIZE / numAccounts))
    ))
  }

  indexThreadsForAccount(accountId, indexSize) {
    const chunkSize = Math.floor(indexSize / CHUNKS_PER_ACCOUNT)
    const chunks = Promise.resolve(_.times(CHUNKS_PER_ACCOUNT, () => chunkSize))

    return chunks.each((size, idx) => {
      return DatabaseStore.findAll(Thread)
      .where({accountId})
      .limit(size)
      .offset(size * idx)
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .then((threads) => {
        return Promise.all(
          threads.map(thread => this.indexThread(thread))
        ).then(() => {
          return new Promise((resolve) => setTimeout(resolve, INDEXING_WAIT))
        })
      })
    })
  }

  indexThread(thread) {
    return (
      this.getIndexData(thread)
      .then((indexData) => (
        DatabaseStore.indexModel(thread, indexData)
      ))
    )
  }

  updateThreadIndex(thread) {
    return (
      this.getIndexData(thread)
      .then((indexData) => (
        DatabaseStore.updateModelIndex(thread, indexData)
      ))
    )
  }

  getIndexData(thread) {
    const messageBodies = (
      thread.messages()
      .then((messages) => (
        Promise.resolve(
          messages
          .map(({body, snippet}) => (
            !_.isString(body) ?
              {snippet} :
              {body: QuotedHTMLTransformer.removeQuotedHTML(body)}
          ))
          .map(({body, snippet}) => (
            snippet ?
              snippet :
              Utils.extractTextFromHtml(body, {maxLength: MESSAGE_BODY_LENGTH}).replace(/(\s)+/g, ' ')
          ))
          .join(' ')
        )
      ))
    )
    const participants = (
      thread.participants
      .map(({name, email}) => `${name} ${email}`)
      .join(" ")
    )

    return Promise.props({
      participants,
      body: messageBodies,
      subject: thread.subject,
    })
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }
}

export default new SearchIndexStore()
