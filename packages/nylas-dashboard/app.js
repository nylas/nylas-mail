const Hapi = require('hapi');
const HapiWebSocket = require('hapi-plugin-websocket');
const Inert = require('inert');
const {DatabaseConnector, PubsubConnector, SchedulerUtils} = require(`nylas-core`);

global.Promise = require('bluebird');

const server = new Hapi.Server();
server.connection({ port: process.env.PORT / 1 + 1 || 5101 });

DatabaseConnector.forShared().then(({Account}) => {
  server.register([HapiWebSocket, Inert], () => {
    server.route({
      method: "POST",
      path: "/accounts",
      config: {
        plugins: {
          websocket: {
            only: true,
            connect: (wss, ws) => {
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
});
