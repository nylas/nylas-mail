const Hapi = require('hapi');
const HapiWebSocket = require('hapi-plugin-websocket');
const Inert = require('inert');
const {DatabaseConnector, PubsubConnector, SchedulerUtils, Logger} = require(`nylas-core`);
const fs = require('fs');
const path = require('path');

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

const onAccountsWebsocketConnected = (wss, ws) => {
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
};

const onAccountsWebsocketConnectedFake = (wss, ws) => {
  const accts = [];
  for (let ii = 0; ii < 300; ii++) {
    const acct = {
      id: ii,
      email_address: `halla+${ii}@nylas.com`,
      object: "account",
      organization_unit: "folder",
      provider: "imap",
      connection_settings: {
        imap_host: "imap.mail.me.com",
        imap_port: 993,
        smtp_host: "smtp.mail.me.com",
        smtp_port: 0,
        ssl_required: true,
      },
      sync_policy: {
        afterSync: "idle",
        intervals: {
          active: 30000,
          inactive: 300000,
        },
        folderSyncOptions: {
          deepFolderScan: 600000,
        },
      },
      sync_error: null,
      first_sync_completion: 0,
      last_sync_completions: [],
      created_at: "2016-07-13T00:49:25.000Z",
    };
    ws.send(JSON.stringify({ cmd: "ACCOUNT", payload: acct }));
    accts.push(acct);
  }
  setInterval(() => {
    const acct = accts[Math.floor(Math.random() * accts.length)];
    ws.send(JSON.stringify({ cmd: "ACCOUNT", payload: acct }));
  }, 250);
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
          connect: onAccountsWebsocketConnectedFake,
          disconnect: function disconnect() {
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
    global.Logger.info({uri: server.info.uri}, 'Dashboard running');
  });
});
