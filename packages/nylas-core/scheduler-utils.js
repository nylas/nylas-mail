const ACCOUNTS_UNCLAIMED = 'accounts:unclaimed';
const ACCOUNTS_CLAIMED_PREFIX = 'accounts:id-';
const ACCOUNTS_FOR = (id) => `${ACCOUNTS_CLAIMED_PREFIX}${id}`;
const ACTIVE_KEY_FOR = (id) => `active:${id}`

const HEARTBEAT_FOR = (id) => `heartbeat:${id}`;
const HEARTBEAT_EXPIRES = 30; // 2 min in prod?

const CLAIM_DURATION = 10 * 60 * 1000; // 2 hours on prod?

const PubsubConnector = require('./pubsub-connector');
const MessageTypes = require('./message-types')

const forEachAccountList = (forEachCallback) => {
  const client = PubsubConnector.broadcastClient();
  return Promise.each(client.keysAsync(`accounts:*`), (key) => {
    const processId = key.replace('accounts:', '');
    return client.lrangeAsync(key, 0, 20000).then((foundIds) =>
      forEachCallback(processId, foundIds)
    )
  });
}

const assignPolicy = (accountId, policy) => {
  console.log(`Changing policy for ${accountId} to ${JSON.stringify(policy)}`)
  const DatabaseConnector = require('./database-connector');
  DatabaseConnector.forShared().then(({Account}) => {
    Account.find({where: {id: accountId}}).then((account) => {
      account.syncPolicy = policy;
      account.save()
    })
  });
}

const checkIfAccountIsActive = (accountId) => {
  const client = PubsubConnector.broadcastClient();
  const key = ACTIVE_KEY_FOR(accountId);
  return client.getAsync(key).then((val) => val !== null)
}

const listActiveAccounts = () => {
  const client = PubsubConnector.broadcastClient();
  const keyBase = ACTIVE_KEY_FOR('');

  return client.keysAsync(`${keyBase}*`).then((keys) =>
    keys.map(k => k.replace(keyBase, ''))
  );
}

const notifyAccountIsActive = (accountId) => {
  const client = PubsubConnector.broadcastClient();
  const key = ACTIVE_KEY_FOR(accountId);
  client.incrAsync(key).then((val) => {
    client.expireAsync(key, 5 * 60 * 1000); // 5 min
    if (val === 1) {
      PubsubConnector.notify({
        accountId: accountId,
        type: MessageTypes.ACCOUNT_UPDATED,
      });
    }
  });
}

module.exports = {
  ACCOUNTS_UNCLAIMED,
  ACCOUNTS_CLAIMED_PREFIX,
  ACCOUNTS_FOR,
  HEARTBEAT_FOR,
  HEARTBEAT_EXPIRES,
  CLAIM_DURATION,

  assignPolicy,
  forEachAccountList,
  listActiveAccounts,
  notifyAccountIsActive,
  checkIfAccountIsActive,
}
