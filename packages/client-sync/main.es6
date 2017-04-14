/* eslint global-require: 0 */
import Sequelize from 'sequelize'; // eslint-disable-line
import {ComponentRegistry} from 'nylas-exports'
import {createLogger} from './src/shared/logger'
import shimSequelize from './src/shared/shim-sequelize'
import {removeDuplicateAccountsWithOldSettings} from './src/shared/dedupe-accounts'
import SendTaskManager from './src/local-sync-worker/send-task-manager'

export async function activate() {
  shimSequelize(Sequelize);
  global.Logger = createLogger()
  require('./src/local-api');

  // NOTE: See https://phab.nylas.com/D4425 for explanation of why this check
  // is necessary
  // TODO remove this check after it no longer affects users
  await removeDuplicateAccountsWithOldSettings()

  require('./src/local-sync-worker');
  SendTaskManager.activate();
  const Root = require('./src/local-sync-dashboard/root').default;
  ComponentRegistry.register(Root, {role: 'Developer:LocalSyncUI'});
}

export function deactivate() {
  SendTaskManager.deactivate()
}
