const {
  DatabaseConnector,
  PubsubConnector,
  SchedulerUtils,
} = require(`nylas-core`);

function onWebsocketConnected(wss, ws) {
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
}

function onWebsocketDisconnected() {
  clearInterval(this.pollInterval);
  this.observable.dispose();
}

function onWebsocketConnectedFake(wss, ws) {
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

module.exports = (server) => {
  server.route({
    method: "POST",
    path: "/websocket",
    config: {
      plugins: {
        websocket: {
          only: true,
          connect: onWebsocketConnected,
          disconnect: onWebsocketDisconnected,
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
}
