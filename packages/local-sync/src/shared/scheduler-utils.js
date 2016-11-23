const ACCOUNTS_UNCLAIMED = 'accounts:unclaimed';
const ACCOUNTS_CLAIMED_PREFIX = 'accounts:id-';
const ACCOUNTS_FOR = (id) => `${ACCOUNTS_CLAIMED_PREFIX}${id}`;
const ACTIVE_KEY_FOR = (id) => `active:${id}`

const HEARTBEAT_FOR = (id) => `heartbeat:${id}`;
const HEARTBEAT_EXPIRES = 30; // 2 min in prod?

const CLAIM_DURATION = 10 * 60 * 1000; // 2 hours on prod?

const PromiseUtils = require('./promise-utils')
const LocalPubsubConnector = require('./pubsub-connector');
const MessageTypes = require('./message-types')

const forEachAccountList = (forEachCallback) => {
  const client = LocalPubsubConnector.broadcastClient();
  return PromiseUtils.each(client.keysAsync(`accounts:*`), (key) => {
    const processId = key.replace('accounts:', '');
    return client.lrangeAsync(key, 0, 20000).then((foundIds) =>
      forEachCallback(processId, foundIds)
    )
  });
}

const assignPolicy = (accountId, policy) => {
  const log = global.Logger || console
  log.info({policy, account_id: accountId}, `Changing single policy`)

  const LocalDatabaseConnector = require('./local-database-connector');
  return LocalDatabaseConnector.forShared().then(({Account}) => {
    Account.find({where: {id: accountId}}).then((account) => {
      account.syncPolicy = policy;
      account.save()
    })
  });
}

const assignPolicyToAcounts = (accountIds, policy) => {
  const log = global.Logger || console
  log.info({policy, account_ids: accountIds}, `Changing multiple policies`)

  const LocalDatabaseConnector = require('./local-database-connector');
  return LocalDatabaseConnector.forShared().then(({Account}) => {
    Account.findAll({where: {id: {$or: accountIds}}}).then((accounts) => {
      for (const account of accounts) {
        account.syncPolicy = policy;
        account.save()
      }
    })
  });
}

const checkIfAccountIsActive = (accountId) => {
  const client = LocalPubsubConnector.broadcastClient();
  const key = ACTIVE_KEY_FOR(accountId);
  return client.getAsync(key).then((val) => val !== null)
}

const listActiveAccounts = () => {
  const client = LocalPubsubConnector.broadcastClient();
  const keyBase = ACTIVE_KEY_FOR('');

  return client.keysAsync(`${keyBase}*`).then((keys) =>
    keys.map(k => k.replace(keyBase, ''))
  );
}

const markAccountIsActive = (accountId) => {
  const client = LocalPubsubConnector.broadcastClient();
  const key = ACTIVE_KEY_FOR(accountId);
  client.incrAsync(key).then((val) => {
    client.expireAsync(key, 5 * 60); // 5 min in seconds
    if (val === 1) {
      LocalPubsubConnector.notifyAccount(accountId, {
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
  assignPolicyToAcounts,
  forEachAccountList,
  listActiveAccounts,
  markAccountIsActive,
  checkIfAccountIsActive,
}
