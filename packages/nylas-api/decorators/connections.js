/* eslint func-names:0 */

const {DatabaseConnectionFactory} = require(`nylas-core`);

module.exports = (server) => {
  server.decorate('request', 'getAccountDatabase', function () {
    const account = this.auth.credentials;
    return DatabaseConnectionFactory.forAccount(account.id);
  });
}
