import {ComponentRegistry, WorkspaceStore} from 'nylas-exports'
import SearchBar from './search-bar'

export default {
  configDefaults: {
    showOnRightSide: false,
  },

  activate() {
    ComponentRegistry.register(SearchBar, {
      location: WorkspaceStore.Location.ThreadList.Toolbar,
    })
  },

  deactivate() {
    ComponentRegistry.unregister(SearchBar)
  },
}
