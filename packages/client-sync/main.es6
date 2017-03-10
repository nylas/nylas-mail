/* eslint global-require: 0 */
import Sequelize from 'sequelize'; // eslint-disable-line
import {ComponentRegistry} from 'nylas-exports'
import {createLogger} from './src/shared/logger'
import shimSequelize from './src/shared/shim-sequelize'

export function activate() {
  shimSequelize(Sequelize);
  global.Logger = createLogger()
  require('./src/local-api');
  require('./src/local-sync-worker');

  const Root = require('./src/local-sync-dashboard/root').default;
  ComponentRegistry.register(Root, {role: 'Developer:LocalSyncUI'});
}

export function deactivate() {

}
