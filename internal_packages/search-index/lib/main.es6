import ThreadSearchIndexStore from './thread-search-index-store'
import ContactSearchIndexer from './contact-search-indexer'
import EventSearchIndexer from './event-search-indexer'


export function activate() {
  ThreadSearchIndexStore.activate()
  ContactSearchIndexer.activate()
  EventSearchIndexer.activate()
}

export function deactivate() {
  ThreadSearchIndexStore.deactivate()
  ContactSearchIndexer.deactivate()
  EventSearchIndexer.deactivate()
}
