
export function activate() {
  require('./src/local-api/app.js');
  require('./src/local-sync-worker/app.js');
  console.log('wtf dude')
}

export function deactivate() {

}
