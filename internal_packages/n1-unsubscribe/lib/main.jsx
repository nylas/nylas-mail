const {ComponentRegistry} = require('nylas-exports'); // eslint-disable-line
const {
  ThreadUnsubscribeQuickActionButton,
  ThreadUnsubscribeToolbarButton,
} = require('./ui/unsubscribe-buttons');
const settings = require('./settings');

settings.configure();

// Configure plugin updater
const config = require(`${__dirname}/../package.json`); // eslint-disable-line
// const n1pluginupdater = require('n1pluginupdater');

module.exports = {
  // Activate is called when the package is loaded. If your package previously
  // saved state using `serialize` it is provided.
  //
  activate: () => {
    // n1pluginupdater.checkForUpdate({
    //   repositoryName: "n1-unsubscribe",
    //   repositoryOwner: "colinking",
    //   currentVersion: config.version,
    // });
    // ComponentRegistry.register(ThreadUnsubscribeBulkAction,
    //   { role: 'ThreadListBulkAction' });
    // //   role: 'thread:BulkAction'
    ComponentRegistry.register(ThreadUnsubscribeQuickActionButton,
      { role: 'ThreadListQuickAction' });
    ComponentRegistry.register(ThreadUnsubscribeToolbarButton,
      { role: 'ThreadActionsToolbarButton' });
  },

  // This **optional** method is called when the window is shutting down,
  // or when your package is being updated or disabled. If your package is
  // watching any files, holding external resources, providing commands or
  // subscribing to events, release them here.
  //
  deactivate: () => {
    // n1pluginupdater.deactivate();
    // ComponentRegistry.register(ThreadUnsubscribeBulkAction);
    ComponentRegistry.unregister(ThreadUnsubscribeQuickActionButton);
    ComponentRegistry.unregister(ThreadUnsubscribeToolbarButton);
  },
}
