const ACCOUNTS_UNCLAIMED = 'accounts:unclaimed';
const ACCOUNTS_CLAIMED_PREFIX = 'accounts:id-';
const ACCOUNTS_FOR = (id) => `${ACCOUNTS_CLAIMED_PREFIX}${id}`;
const HEARTBEAT_FOR = (id) => `heartbeat:${id}`;
const HEARTBEAT_EXPIRES = 30; // 2 min in prod?
const CLAIM_DURATION = 10 * 60 * 1000; // 2 hours on prod?

const PubsubConnector = require('./pubsub-connector')

const forEachAccountList = (forEachCallback) => {
  const client = PubsubConnector.broadcastClient();
  return Promise.each(client.keysAsync(`accounts:*`), (key) => {
    const processId = key.replace('accounts:', '');
    return client.lrangeAsync(key, 0, 20000).then((foundIds) =>
      forEachCallback(processId, foundIds)
    )
  });
}

module.exports = {
  ACCOUNTS_UNCLAIMED,
  ACCOUNTS_CLAIMED_PREFIX,
  ACCOUNTS_FOR,
  HEARTBEAT_FOR,
  HEARTBEAT_EXPIRES,
  CLAIM_DURATION,

  forEachAccountList,
}
