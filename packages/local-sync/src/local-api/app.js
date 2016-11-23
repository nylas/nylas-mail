const Metrics = require(`../local-sync-metrics`)
Metrics.startCapturing('nylas-k2-api')

const Hapi = require('hapi');
const HapiSwagger = require('hapi-swagger');
const HapiBoom = require('hapi-boom-decorators')
const HapiBasicAuth = require('hapi-auth-basic');
const Inert = require('inert');
const Vision = require('vision');
const Package = require('../../package');
const fs = require('fs');
const path = require('path');
const {DatabaseConnector, SchedulerUtils, Logger} = require(`nylas-core`);

global.Metrics = Metrics
global.Logger = Logger.createLogger('nylas-k2-api')

const onUnhandledError = (err) => {
  global.Logger.fatal(err, 'Unhandled error')
  global.Metrics.reportError(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

const server = new Hapi.Server({
  connections: {
    router: {
      stripTrailingSlash: true,
    },
  },
});

server.connection({ port: process.env.PORT });

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
    getSharedDb = DatabaseConnector.forShared()
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
        SchedulerUtils.markAccountIsActive(account.id)
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

  attach('./routes/')
  attach('./decorators/')

  server.auth.strategy('api-consumer', 'basic', { validateFunc: validate });
  server.auth.default('api-consumer');

  server.start((startErr) => {
    if (startErr) { throw startErr; }
    global.Logger.info({url: server.info.uri}, 'API running');
  });
});
