import {ipcRenderer} from 'electron';
import {PreferencesUIStore,
  Actions,
  WorkspaceStore,
  ComponentRegistry} from 'nylas-exports';

import PreferencesRoot from './preferences-root';
import PreferencesGeneral from './tabs/preferences-general';
import PreferencesAccounts from './tabs/preferences-accounts';
import PreferencesAppearance from './tabs/preferences-appearance';
import PreferencesKeymaps from './tabs/preferences-keymaps';
import PreferencesMailRules from './tabs/preferences-mail-rules';


export function activate() {
  PreferencesUIStore.registerPreferencesTab(new PreferencesUIStore.TabItem({
    tabId: 'General',
    displayName: 'General',
    component: PreferencesGeneral,
    order: 1,
  }))
  PreferencesUIStore.registerPreferencesTab(new PreferencesUIStore.TabItem({
    tabId: 'Accounts',
    displayName: 'Accounts',
    component: PreferencesAccounts,
    order: 2,
  }))
  PreferencesUIStore.registerPreferencesTab(new PreferencesUIStore.TabItem({
    tabId: 'Appearance',
    displayName: 'Appearance',
    component: PreferencesAppearance,
    order: 3,
  }))
  PreferencesUIStore.registerPreferencesTab(new PreferencesUIStore.TabItem({
    tabId: 'Shortcuts',
    displayName: 'Shortcuts',
    component: PreferencesKeymaps,
    order: 4,
  }))
  PreferencesUIStore.registerPreferencesTab(new PreferencesUIStore.TabItem({
    tabId: 'Mail Rules',
    displayName: 'Mail Rules',
    component: PreferencesMailRules,
    order: 5,
  }))

  WorkspaceStore.defineSheet('Preferences', {}, {
    split: ['Preferences'],
    list: ['Preferences'],
  });

  ComponentRegistry.register(PreferencesRoot, {
    location: WorkspaceStore.Location.Preferences,
  });

  Actions.openPreferences.listen(this._openPreferences);
  ipcRenderer.on('open-preferences', () => this._openPreferences());
}

export function _openPreferences() {
  ipcRenderer.send('command', 'application:show-main-window');
  if (WorkspaceStore.topSheet() !== WorkspaceStore.Sheet.Preferences) {
    Actions.pushSheet(WorkspaceStore.Sheet.Preferences);
  }
}

export function deactivate() {
}

export function serialize() {
  return this.state;
}
