import {createLogger} from './src/shared/logger'

export function activate() {
  global.Logger = createLogger('local-sync')
  // require('./src/local-api/app.js');
  require('./src/local-sync-worker/app.js');
}

export function deactivate() {

}
