import ThreadSearchIndexStore from './thread-search-index-store'
import ContactSearchIndexer from './contact-search-indexer'
// import EventSearchIndexer from './event-search-indexer'


export function activate() {
  ThreadSearchIndexStore.activate()
  ContactSearchIndexer.activate()
  // TODO Calendar feature has been punted, we will disable this indexer for now
  // EventSearchIndexer.activate(indexer)
}

export function deactivate() {
  ThreadSearchIndexStore.deactivate()
  ContactSearchIndexer.deactivate()
  // EventSearchIndexer.deactivate()
}
