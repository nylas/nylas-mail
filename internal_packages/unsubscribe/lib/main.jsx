import {ComponentRegistry, PreferencesUIStore} from 'nylas-exports';
import {ThreadUnsubscribeQuickActionButton, ThreadUnsubscribeToolbarButton}
  from './ui/unsubscribe-buttons';
import UnsubscribePreferences from './ui/unsubscribe-preferences';

export const config = {
  defaultBrowser: {
    "title": "Default browser",
    "type": "string",
    "default": "popup",
    "enum": ["popup", "native"],
    'enumLabels': ["Popup Window", "Native Browser"],
  },
  handleThreads: {
    "title": "Default unsubscribe behaivor",
    "type": "string",
    "default": "archive",
    "enum": ["archive", "trash", "none"],
    'enumLabels': ["Archive", "Trash", "None"],
  },
  confirmForEmail: {
    "title": "Confirm before sending email-based unsubscribe requests",
    "type": "boolean",
    "default": false,
  },
  confirmForBrowser: {
    "title": "Confirm before opening web-based unsubscribe links",
    "type": "boolean",
    "default": false,
  },
}

export function activate() {
  ComponentRegistry.register(ThreadUnsubscribeQuickActionButton,
    { role: 'ThreadListQuickAction' });
  ComponentRegistry.register(ThreadUnsubscribeToolbarButton,
    { role: 'ThreadActionsToolbarButton' });

  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: 'Unsubscribe',
    displayName: "Unsubscribe",
    component: UnsubscribePreferences,
  });
  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);
}

export function deactivate() {
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab);
  ComponentRegistry.unregister(ThreadUnsubscribeQuickActionButton);
  ComponentRegistry.unregister(ThreadUnsubscribeToolbarButton);
}
