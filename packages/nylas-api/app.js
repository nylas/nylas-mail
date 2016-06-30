const Hapi = require('hapi');
const HapiSwagger = require('hapi-swagger');
const HapiBoom = require('hapi-boom-decorators')
const HapiBasicAuth = require('hapi-auth-basic');
const Inert = require('inert');
const Vision = require('vision');
const Package = require('./package');
const fs = require('fs');
const path = require('path');

global.Promise = require('bluebird');
global.NylasError = require('nylas-core').NylasError;

const server = new Hapi.Server({
  connections: {
    router: {
      stripTrailingSlash: true,
    },
  },
});

server.connection({ port: process.env.PORT || 5100 });

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
const {DatabaseConnector, SchedulerUtils} = require(`nylas-core`)
DatabaseConnector.forShared().then((db) => {
  sharedDb = db;
});

const validate = (request, username, password, callback) => {
  const {AccountToken} = sharedDb;

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
      SchedulerUtils.markAccountIsActive(account.id)
      callback(null, true, account);
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

  attach('./routes/')
  attach('./decorators/')

  server.auth.strategy('api-consumer', 'basic', { validateFunc: validate });
  server.auth.default('api-consumer');

  server.start((startErr) => {
    if (startErr) { throw startErr; }
    console.log('API running at:', server.info.uri);
  });
});
