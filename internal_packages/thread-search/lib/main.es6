import {ComponentRegistry, WorkspaceStore} from 'nylas-exports'
import SearchBar from './search-bar'

export const configDefaults = {
  showOnRightSide: false,
}

export function activate() {
  ComponentRegistry.register(SearchBar, {
    location: WorkspaceStore.Location.ThreadList.Toolbar,
  })
}

export function deactivate() {
  ComponentRegistry.unregister(SearchBar)
}
