const LocalDatabaseConnector = require('../../shared/local-database-connector');
const LocalPubsubConnector = require('../../shared/local-pubsub-connector')
const SchedulerUtils = require('../../shared/scheduler-utils')

function onWebsocketConnected(wss, ws) {
  let toSend;
  function resetToSend() {
    toSend = {
      updatedAccounts: [],
      activeAccountIds: [],
      assignments: {},
      processLoads: {},
    };
  }
  resetToSend();

  function sendUpdate() {
    ws.send(JSON.stringify({cmd: "UPDATE", payload: toSend}));
    resetToSend();
  }

  LocalDatabaseConnector.forShared().then(({Account}) => {
    Account.findAll().then((accounts) => {
      accounts.forEach((acct) => {
        toSend.updatedAccounts.push(acct);
        if (toSend.updatedAccounts.length >= 50) {
          sendUpdate();
        }
      });
      sendUpdate();
    });

    this.observable = LocalPubsubConnector.observeAllAccounts().subscribe((accountId) => {
      Account.find({where: {id: accountId}}).then((acct) => {
        toSend.updatedAccounts.push(acct);
      });
    });

    this.pollInterval = setInterval(() => {
      const getActiveIds = SchedulerUtils.listActiveAccounts().then((accountIds) => {
        toSend.activeAccountIds = accountIds;
      });
      const getAssignments = SchedulerUtils.forEachAccountList((identity, accountIds) => {
        toSend.processLoads[identity] = accountIds;
        for (const accountId of accountIds) {
          toSend.assignments[accountId] = identity;
        }
      })

      Promise.all([getActiveIds, getAssignments]).then(() => {
        sendUpdate();
      })
    }, 1000);
  });
}

function onWebsocketDisconnected() {
  clearInterval(this.pollInterval);
  this.observable.dispose();
}

function onWebsocketConnectedFake(wss, ws) {
  const accts = [];
  for (let ii = 0; ii < 100; ii++) {
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
    ws.send(JSON.stringify({ cmd: "UPDATE", payload: {
      updatedAccounts: [acct],
      activeAccountIds: [],
      assignments: {},
    }}));
    accts.push(acct);
  }
  setInterval(() => {
    const acct = accts[Math.floor(Math.random() * accts.length)];
    ws.send(JSON.stringify({ cmd: "UPDATE", payload: {
      updatedAccounts: [acct],
      activeAccountIds: [],
      assignments: {},
    }}));
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
