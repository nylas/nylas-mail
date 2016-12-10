const {ComponentRegistry} = require('nylas-exports');
const {
  ThreadUnsubscribeQuickActionButton,
  ThreadUnsubscribeToolbarButton,
} = require('./ui/unsubscribe-buttons');

module.exports = {
  config: {
    useNativeBrowser: {
      "description": "Open web-based unsubscribe links in your native browser (Chrome, Firefox, etc.) instead of a popup window in N1",
      "type": "boolean",
      "default": false,
    },
    handleThreads: {
      "description": "Determines where emails are moved after unsubscribing",
      "type": "string",
      "default": "archive",
      "enum": ["archive", "trash", "none"],
    },
    confirmForEmail: {
      "description": "Open a confirmation window before sending an unsubscribe request over email",
      "type": "boolean",
      "default": false,
    },
    confirmForBrowser: {
      "description": "Open a confirmation window before opening web-based unsubscribe links",
      "type": "boolean",
      "default": false,
    },
    debug: {
      "description": "Enable debug messages",
      "type": "boolean",
      "default": true,
    },
  },
  activate: () => {
    ComponentRegistry.register(ThreadUnsubscribeQuickActionButton,
      { role: 'ThreadListQuickAction' });
    ComponentRegistry.register(ThreadUnsubscribeToolbarButton,
      { role: 'ThreadActionsToolbarButton' });
  },
  deactivate: () => {
    ComponentRegistry.unregister(ThreadUnsubscribeQuickActionButton);
    ComponentRegistry.unregister(ThreadUnsubscribeToolbarButton);
  },
}
