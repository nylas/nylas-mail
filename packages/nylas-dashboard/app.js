const Hapi = require('hapi');
const HapiWebSocket = require('hapi-plugin-websocket');
const Inert = require('inert');
const {DatabaseConnector, PubsubConnector, SchedulerUtils} = require(`nylas-core`);
const {forEachAccountList} = SchedulerUtils;

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
              Account.findAll().then((accts) => {
                accts.forEach((acct) => {
                  ws.send(JSON.stringify({ cmd: "ACCOUNT", payload: acct }));
                });
              });
              this.redis = PubsubConnector.buildClient();
              this.redis.on('pmessage', (pattern, channel) => {
                Account.find({where: {id: channel.replace('a-', '')}}).then((acct) => {
                  ws.send(JSON.stringify({ cmd: "ACCOUNT", payload: acct }));
                });
              });
              this.redis.psubscribe(PubsubConnector.channelForAccount('*'));
              this.assignmentsInterval = setInterval(() => {
                const assignments = {};
                forEachAccountList((identity, accountIds) => {
                  for (const accountId of accountIds) {
                    assignments[accountId] = identity;
                  }
                }).then(() =>
                  ws.send(JSON.stringify({ cmd: "ASSIGNMENTS", payload: assignments}))
                )
              }, 1000);
            },
            disconnect: () => {
              clearInterval(this.assignmentsInterval);
              this.redis.quit();
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
