/* eslint global-require: 0 */
import {ComponentRegistry} from 'nylas-exports'
import {createLogger} from './src/shared/logger'

export function activate() {
  global.Logger = createLogger()
  require('./src/local-api');
  require('./src/local-sync-worker');

  const Root = require('./src/local-sync-dashboard/root').default;
  ComponentRegistry.register(Root, {role: 'Developer:LocalSyncUI'});
}

export function deactivate() {

}
