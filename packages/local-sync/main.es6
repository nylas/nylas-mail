/* eslint global-require: 0 */
import {ComponentRegistry} from 'nylas-exports'
import {createLogger} from './src/shared/logger'

export function activate() {
  global.Logger = createLogger('local-sync')
  require('./src/local-api/app');
  require('./src/local-sync-worker/app');

  const Root = require('./src/local-sync-dashboard/root').default;
  ComponentRegistry.register(Root, {role: 'Developer:LocalSyncUI'});
}

export function deactivate() {

}
