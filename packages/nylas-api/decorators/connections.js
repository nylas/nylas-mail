/* eslint func-names:0 */

const {DatabaseConnector} = require(`nylas-core`);

module.exports = (server) => {
  server.decorate('request', 'getAccountDatabase', function () {
    const account = this.auth.credentials;
    return DatabaseConnector.forAccount(account.id);
  });
}
