
export function activate() {
  require('./src/nylas-api/app.js');
  require('./src/nylas-sync/app.js');
  console.log('wtf dude')
}

export function deactivate() {

}
