const Serialization = require('../serialization');
const {DatabaseConnector} = require('nylas-core');

module.exports = (server) => {
  if (process.env.ALLOW_LIST_ACCOUNTS) {
    server.route({
      method: 'GET',
      path: '/accounts',
      config: {
        auth: false,
        description: 'Returns all accounts, only in dev mode. Only intended to easily link N1.',
        tags: ['accounts'],
      },
      handler: (request, reply) => {
        DatabaseConnector.forShared().then((db) => {
          const {Account, AccountToken} = db;

          // N1 assumes that the local sync engine uses the account IDs as the
          // auth tokens. K2 supports real auth tokens out of the box, but we
          // create ones that have value = accountId.
          Account.all().then((accounts) => {
            Promise.all(
              accounts.map(({id}) => AccountToken.create({accountId: id, value: id})
            )).finally(() =>
              reply(accounts.map((account) =>
                Object.assign(account.toJSON(), {id: `${account.id}`, auth_token: `${account.id}`})
              ))
            )
          });
        });
      },
    });
  }

  server.route({
    method: 'GET',
    path: '/account',
    config: {
      description: 'Returns the current account.',
      notes: 'Notes go here',
      tags: ['accounts'],
      validate: {
        params: {
        },
      },
      response: {
        schema: Serialization.jsonSchema('Account'),
      },
    },
    handler: (request, reply) => {
      const account = request.auth.credentials;
      reply(Serialization.jsonStringify(account));
    },
  });

  server.route({
    method: 'DELETE',
    path: '/account',
    config: {
      description: 'Deletes the current account and all data from the Nylas Cloud.',
      notes: 'Notes go here',
      tags: ['accounts'],
      validate: {
        params: {
        },
      },
    },
    handler: (request, reply) => {
      const account = request.auth.credentials;
      account.destroy().then((saved) =>
        DatabaseConnector.destroyAccountDatabase(saved.id).then(() =>
          reply(Serialization.jsonStringify({status: 'success'}))
        )
      ).catch((err) => {
        reply(err).code(500);
      })
    },
  });
};
