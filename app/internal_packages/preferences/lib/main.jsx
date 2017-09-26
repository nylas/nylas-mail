/* eslint global-require: 0 */
import { PreferencesUIStore, WorkspaceStore, ComponentRegistry } from 'nylas-exports';

import PreferencesRoot from './preferences-root';

export function activate() {
  PreferencesUIStore.registerPreferencesTab(
    new PreferencesUIStore.TabItem({
      tabId: 'General',
      displayName: 'General',
      componentClassFn: () => require('./tabs/preferences-general').default,
      order: 1,
    })
  );
  PreferencesUIStore.registerPreferencesTab(
    new PreferencesUIStore.TabItem({
      tabId: 'Accounts',
      displayName: 'Accounts',
      componentClassFn: () => require('./tabs/preferences-accounts').default,
      order: 2,
    })
  );
  PreferencesUIStore.registerPreferencesTab(
    new PreferencesUIStore.TabItem({
      tabId: 'Subscription',
      displayName: 'Subscription',
      componentClassFn: () => require('./tabs/preferences-identity').default,
      order: 3,
    })
  );
  PreferencesUIStore.registerPreferencesTab(
    new PreferencesUIStore.TabItem({
      tabId: 'Appearance',
      displayName: 'Appearance',
      componentClassFn: () => require('./tabs/preferences-appearance').default,
      order: 4,
    })
  );
  PreferencesUIStore.registerPreferencesTab(
    new PreferencesUIStore.TabItem({
      tabId: 'Shortcuts',
      displayName: 'Shortcuts',
      componentClassFn: () => require('./tabs/preferences-keymaps').default,
      order: 5,
    })
  );
  PreferencesUIStore.registerPreferencesTab(
    new PreferencesUIStore.TabItem({
      tabId: 'Mail Rules',
      displayName: 'Mail Rules',
      componentClassFn: () => require('./tabs/preferences-mail-rules').default,
      order: 6,
    })
  );

  WorkspaceStore.defineSheet(
    'Preferences',
    {},
    {
      split: ['Preferences'],
      list: ['Preferences'],
    }
  );

  ComponentRegistry.register(PreferencesRoot, {
    location: WorkspaceStore.Location.Preferences,
  });
}

export function deactivate() {}

export function serialize() {
  return this.state;
}
