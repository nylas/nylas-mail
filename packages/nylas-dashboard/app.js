const Hapi = require('hapi');
const HapiWebSocket = require('hapi-plugin-websocket');
const Inert = require('inert');
const {DatabaseConnector, PubsubConnector, SchedulerUtils} = require(`nylas-core`);
const fs = require('fs');
const path = require('path');

global.Promise = require('bluebird');

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
    method: "POST",
    path: "/accounts",
    config: {
      plugins: {
        websocket: {
          only: true,
          connect: (wss, ws) => {
            DatabaseConnector.forShared().then(({Account}) => {
              Account.findAll().then((accounts) => {
                accounts.forEach((acct) => {
                  ws.send(JSON.stringify({ cmd: "ACCOUNT", payload: acct }));
                });
              });

              this.observable = PubsubConnector.observeAllAccounts().subscribe((accountId) => {
                Account.find({where: {id: accountId}}).then((acct) => {
                  ws.send(JSON.stringify({ cmd: "ACCOUNT", payload: acct }));
                });
              });

              this.pollInterval = setInterval(() => {
                SchedulerUtils.listActiveAccounts().then((accountIds) => {
                  ws.send(JSON.stringify({ cmd: "ACTIVE", payload: accountIds}))
                });
                const assignments = {};
                SchedulerUtils.forEachAccountList((identity, accountIds) => {
                  for (const accountId of accountIds) {
                    assignments[accountId] = identity;
                  }
                }).then(() =>
                  ws.send(JSON.stringify({ cmd: "ASSIGNMENTS", payload: assignments}))
                )
              }, 1000);
            });
          },
          disconnect: () => {
            clearInterval(this.pollInterval);
            this.observable.dispose();
          },
        },
      },
    },
    handler: (request, reply) => {
      if (request.payload.cmd === "PING") {
        reply(JSON.stringify({ result: "PONG" }));
        return;
      }
    },
  });

  server.route({
    method: 'GET',
    path: '/ping',
    config: {
      auth: false,
    },
    handler: (request, reply) => {
      console.log("---> Ping!")
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
    console.log('Dashboard running at:', server.info.uri);
  });
});
