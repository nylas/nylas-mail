/* eslint import/no-dynamic-require: 0 */
/* eslint global-require: 0 */
const Hapi = require('hapi');
const HapiSwagger = require('hapi-swagger');
const HapiBoom = require('hapi-boom-decorators')
const HapiBasicAuth = require('hapi-auth-basic');
const Inert = require('inert');
const Vision = require('vision');
const Package = require('../../package');
const fs = require('fs');
const path = require('path');
const LocalDatabaseConnector = require('../shared/local-database-connector')

const server = new Hapi.Server({
  connections: {
    router: {
      stripTrailingSlash: true,
    },
  },
});

let port = 2578;
if (NylasEnv.inDevMode()) port = 1337;
server.connection({port});

const plugins = [Inert, Vision, HapiBasicAuth, HapiBoom, {
  register: HapiSwagger,
  options: {
    info: {
      title: 'Nylas API Documentation',
      version: Package.version,
    },
  },
}];

let sharedDb = null;

const validate = (request, username, password, callback) => {
  let getSharedDb = null;
  if (sharedDb) {
    getSharedDb = Promise.resolve(sharedDb)
  } else {
    getSharedDb = LocalDatabaseConnector.forShared()
  }

  getSharedDb.then((db) => {
    sharedDb = db;
    const {AccountToken} = db;

    AccountToken.find({
      where: {
        value: username,
      },
    }).then((token) => {
      if (!token) {
        callback(null, false, {});
        return
      }
      token.getAccount().then((account) => {
        if (!account) {
          callback(null, false, {});
          return;
        }
        callback(null, true, account);
      });
    });
  });
};

const attach = (directory) => {
  const routesDir = path.join(__dirname, directory)
  fs.readdirSync(routesDir).forEach((filename) => {
    if (filename.endsWith('.js')) {
      const routeFactory = require(path.join(routesDir, filename));
      routeFactory(server);
    }
  });
}

server.register(plugins, (err) => {
  if (err) { throw err; }

  attach('./routes')
  attach('./decorators')

  server.auth.strategy('api-consumer', 'basic', { validateFunc: validate });
  server.auth.default('api-consumer');

  server.start((startErr) => {
    if (startErr) { throw startErr; }
    global.Logger.log('API running', {url: server.info.uri});
  });
});
