
export function activate() {
  require('./nylas-api/app.js');
  require('./nylas-sync/app.js');
  console.log('wtf dude')
}

export function deactivate() {

}
