const Hapi = require('hapi');
const HapiSwagger = require('hapi-swagger');
const HapiBasicAuth = require('hapi-auth-basic');
const Inert = require('inert');
const Vision = require('vision');
const Package = require('./package');
const fs = require('fs');
const path = require('path');

const server = new Hapi.Server();
server.connection({ port: process.env.PORT || 5100 });

const plugins = [Inert, Vision, HapiBasicAuth, {
  register: HapiSwagger,
  options: {
    info: {
      title: 'Nylas API Documentation',
      version: Package.version,
    },
  },
}];

let sharedDb = null;
const {DatabaseConnectionFactory} = require(`nylas-core`)
DatabaseConnectionFactory.forShared().then((db) => {
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
    console.log('Server running at:', server.info.uri);
  });
});
