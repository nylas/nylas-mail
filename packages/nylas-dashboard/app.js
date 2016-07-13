const fs = require('fs');
const path = require('path');
const Inert = require('inert');
const Hapi = require('hapi');
const HapiWebSocket = require('hapi-plugin-websocket');
const {Logger} = require(`nylas-core`);

global.Promise = require('bluebird');
global.Logger = Logger.createLogger('nylas-k2-dashboard')

const server = new Hapi.Server();
server.connection({ port: process.env.PORT });

const attach = (directory) => {
  const routesDir = path.join(__dirname, directory)
  fs.readdirSync(routesDir).forEach((filename) => {
    if (filename.endsWith('.js')) {
      const routeFactory = require(path.join(routesDir, filename));
      routeFactory(server);
    }
  });
}

server.register([HapiWebSocket, Inert], () => {
  attach('./routes/')

  server.route({
    method: 'GET',
    path: '/ping',
    config: {
      auth: false,
    },
    handler: (request, reply) => {
      global.Logger.info("---> Ping!")
      reply("pong")
    },
  });

  server.route({
    method: 'GET',
    path: '/{param*}',
    handler: {
      directory: {
        path: require('path').join(__dirname, 'public'),
      },
    },
  });

  server.start((startErr) => {
    if (startErr) { throw startErr; }
    global.Logger.info({uri: server.info.uri}, 'Dashboard running');
  });
});
