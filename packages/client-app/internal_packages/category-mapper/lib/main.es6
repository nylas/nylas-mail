import {PreferencesUIStore} from 'nylas-exports';
import PreferencesCategoryMapper from './preferences-category-mapper'

export function activate() {
  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: "Folders",
    displayName: "Folders",
    component: PreferencesCategoryMapper,
  });

  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);
}

export function deactivate() {
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.sectionId)
}
