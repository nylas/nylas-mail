import LocalDatabaseConnector from './local-database-connector'
import SyncProcessManager from '../local-sync-worker/sync-process-manager'

// NOTE: See https://phab.nylas.com/D4425 for explanation of why these functions
// are necessary
// TODO remove these after they no longer affect users

export async function preventCreationOfDuplicateAccounts(db, accountParams) {
  try {
    const existing = await db.Account.findOne({where: {emailAddress: accountParams.emailAddress}})
    const id = db.Account.hash(accountParams)
    if (existing && existing.id !== id) {
      console.warn('upsertAccount: Preventing creation of duplicate accounts with different settings')
      await SyncProcessManager.removeWorkerForAccountId(existing.id);
      await LocalDatabaseConnector.destroyAccountDatabase(existing.id);
      await existing.destroy()
      console.warn('upsertAccoun: Prevented creation of duplicate accounts with different settings')
    }
  } catch (err) {
    err.message = `Error removing duplicate account with old settings: ${err.message}`
    NylasEnv.reportError(err)
  }
}

export async function removeDuplicateAccountsWithOldSettings() {
  try {
    const db = await LocalDatabaseConnector.forShared()
    const allAccounts = await db.Account.findAll()
    const accountsByEmail = new Map()
    const dupeAcctsWithOldSettings = []

    for (const account of allAccounts) {
      const {emailAddress: email} = account
      if (accountsByEmail.has(email)) {
        accountsByEmail.get(email).push(account)
      } else {
        accountsByEmail.set(email, [account])
      }
    }
    for (const [email, accounts] of accountsByEmail) {  // eslint-disable-line
      if (accounts.length <= 1) { continue }
      for (const account of accounts) {
        if (!account.connectionSettings.imap_security) {
          dupeAcctsWithOldSettings.push(account)
        }
      }
    }

    if (dupeAcctsWithOldSettings.length === 0) { return }
    console.warn('Sync: Found duplicate accounts with old settings')
    for (const dupeAccount of dupeAcctsWithOldSettings) {
      await LocalDatabaseConnector.destroyAccountDatabase(dupeAccount.id);
      await dupeAccount.destroy()
    }
    console.warn('Sync: Removed duplicate accounts with old settings')
  } catch (err) {
    err.message = `Error removing duplicate account with old settings: ${err.message}`
    NylasEnv.reportError(err)
  }
}
