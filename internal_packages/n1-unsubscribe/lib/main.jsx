const {ComponentRegistry} = require('nylas-exports');
const {
  ThreadUnsubscribeQuickActionButton,
  ThreadUnsubscribeToolbarButton,
} = require('./ui/unsubscribe-buttons');

const settings = require('./settings');
settings.configure();

module.exports = {
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
