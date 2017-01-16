import ThreadSearchIndexStore from './thread-search-index-store'
import ContactSearchIndexer from './contact-search-indexer'
// import EventSearchIndexer from './event-search-indexer'
import SearchIndexer from './search-indexer'


export function activate() {
  const indexer = new SearchIndexer()
  ThreadSearchIndexStore.activate(indexer)
  ContactSearchIndexer.activate(indexer)
  // TODO Calendar feature has been punted, we will disable this indexer for now
  // EventSearchIndexer.activate(indexer)
}

export function deactivate() {
  ThreadSearchIndexStore.deactivate()
  ContactSearchIndexer.deactivate()
  // EventSearchIndexer.deactivate()
}
