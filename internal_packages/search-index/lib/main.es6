import ThreadSearchIndexStore from './thread-search-index-store'
import ContactSearchIndexStore from './contact-search-index-store'


export function activate() {
  ThreadSearchIndexStore.activate()
  ContactSearchIndexStore.activate()
}

export function deactivate() {
  ThreadSearchIndexStore.deactivate()
  ContactSearchIndexStore.deactivate()
}
