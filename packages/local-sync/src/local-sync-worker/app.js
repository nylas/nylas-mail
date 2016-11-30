const {AccountStore} = require('nylas-exports');

const LocalDatabaseConnector = require('../shared/local-database-connector')
const manager = require('./sync-process-manager')

// Right now, it's a bit confusing because N1 has Account objects, and K2 has
// Account objects. We want to sync all K2 Accounts, but when an N1 Account is
// deleted, we want to delete the K2 account too.

async function ensureK2Consistency() {
  const {Account} = await LocalDatabaseConnector.forShared();
  const k2Accounts = await Account.findAll();
  const n1Accounts = AccountStore.accounts();
  const n1Emails = n1Accounts.map(a => a.emailAddress);

  const deletions = [];
  for (const k2Account of k2Accounts) {
    const deleted = !n1Emails.includes(k2Account.emailAddress);
    if (deleted) {
      console.warn(`Deleting K2 account ID ${k2Account.id} which could not be matched to an N1 account.`)
      manager.removeWorkerForAccountId(k2Account.id);
      LocalDatabaseConnector.destroyAccountDatabase(k2Account.id);
      deletions.push(k2Account.destroy());
    }
  }
  return await Promise.all(deletions)
}

ensureK2Consistency().then(() => {
  // Step 1: Start all K2 Accounts
  manager.start();
});

// Step 2: Watch N1 Accounts, ensure consistency when they change.
AccountStore.listen(ensureK2Consistency);

global.manager = manager;
