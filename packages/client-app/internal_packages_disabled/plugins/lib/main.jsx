import {PreferencesUIStore} from 'nylas-exports';
import PluginsView from './preferences-plugins';

export function activate() {
  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: "Plugins",
    displayName: "Plugins",
    component: PluginsView,
  });

  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);
}

export function deactivate() {
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.sectionId)
}
