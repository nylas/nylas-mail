/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */


const Hapi = require('hapi');
const HapiSwagger = require('hapi-swagger');
const HapiBoom = require('hapi-boom-decorators')
const HapiBasicAuth = require('hapi-auth-basic');
const Inert = require('inert');
const Vision = require('vision');
const Package = require('./package');
const fs = require('fs');
const request = require('request');
const path = require('path');

const {Logger, DatabaseConnector, Metrics} = require(`cloud-core`);
Metrics.startCapturing('nylas-k2-api')

global.Metrics = Metrics
global.Logger = Logger.createLogger('nylas-k2-api')

const onUnhandledError = (err) => {
  global.Logger.fatal(err, 'Unhandled error')
  global.Metrics.reportError(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

const server = new Hapi.Server({
  debug: { request: ['error'] },
  connections: {
    router: {
      stripTrailingSlash: true,
    },
  },
});

server.connection({ port: process.env.PORT });

let db = null;
DatabaseConnector.forShared().then((_db) => {
  db = _db;
});

const validate = (incomingRequest, username, password, callback) => {
  // username is an account token
  // password is the user's N1 Identity Token
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
      request("https://billing.nylas.com/n1/user", {
        auth: {
          username: password,
          password: '',
        },
      }, (err, response, identityJSON) => {
        if (err) {
          callback(err, false, {});
          return;
        }
        if (response.statusCode !== 200) {
          callback(new Error(`billing.nylas.com returned a status code ${response.statusCode} when we tried to authenticate this request.`), false, {});
          return;
        }
        global.Logger.info(identityJSON, 'Got billing.nylas.com identity response')
        callback(null, true, {
          account: account,
          identity: identityJSON,
        });
      })
    })
  })
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

const plugins = [Inert, Vision, HapiBasicAuth, HapiBoom, {
  register: HapiSwagger,
  options: {
    info: {
      title: 'N1-Cloud API Documentation',
      version: Package.version,
    },
  },
}];

server.register(plugins, (err) => {
  if (err) { throw err; }

  attach('./src/routes/')
  attach('./decorators/')

  server.auth.strategy('api-consumer', 'basic', { validateFunc: validate });
  server.auth.default('api-consumer');

  server.start((startErr) => {
    if (startErr) { throw startErr; }
    global.Logger.info({url: server.info.uri}, 'API running');
  });
});
