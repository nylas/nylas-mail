export function activate() {
  require('./nylas-api/app.js');
  require('./nylas-sync/app.js');
}

export function deactivate() {

}
