/* eslint func-names:0 */

const LocalDatabaseConnector = require('../../shared/local-database-connector');

module.exports = (server) => {
  server.decorate('request', 'getAccountDatabase', function () {
    const account = this.auth.credentials;
    return LocalDatabaseConnector.forAccount(account.id);
  });
  server.decorate('request', 'logger', () => {
    return global.Logger
  }, {apply: true});
}
