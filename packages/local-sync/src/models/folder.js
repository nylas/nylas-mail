const _ = require('underscore')
const crypto = require('crypto')
const {DatabaseTypes: {JSONColumn}} = require('isomorphic-core');
const {formatImapPath} = require('../shared/imap-paths-utils');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('folder', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    role: Sequelize.STRING,
    /**
     * Sync state has the following shape, and it indicates how much of the
     * folder we've synced and what's next for syncing:
     *
     * {
     *   // Lowest (oldest) IMAP uid we've fetched in folder
     *   fetchedmin,
     *
     *   // Highest (newest) IMAP uid we've fetched in folder
     *   fetchedmax,
     *
     *   // Highest (most recent) uid in the folder. If this changes, it means
     *   // there is new mail we haven't synced
     *   uidnext,
     *
     *   // Flag provided by IMAP server to indicate if we need to indicate if
     *   // we need resync whole folder
     *   uidvalidity,
     *
     *   // Keeps track of the last uid we've scanned for attribtue changes when
     *   // the server doesn't support CONDSTORE
     *   attributeFetchedMax
     *
     *   // Timestamp when we last scanned attribute changes inside this folder
     *   // This is only applicable when the server doesn't support CONDSTORE
     *   lastAttributeScanTime,
     *
     *   // UIDs that failed to be fetched
     *   failedUIDs,
     * }
    */
    syncState: JSONColumn('syncState'),
  }, {
    classMethods: {
      associate({Folder, Message, Thread, ThreadFolder}) {
        Folder.hasMany(Message)
        Folder.belongsToMany(Thread, {through: ThreadFolder})
      },

      hash({boxName, accountId}) {
        return crypto.createHash('sha256').update(`${accountId}${boxName}`, 'utf8').digest('hex')
      },
    },
    instanceMethods: {
      isSyncComplete() {
        if (!this.syncState) { return true }
        return (
          this.syncState.fetchedmin !== null &&
          this.syncState.minUID !== null &&
          this.syncState.fetchedmax !== null &&
          (this.syncState.fetchedmin <= this.syncState.minUID) &&
          (this.syncState.fetchedmax >= this.syncState.uidnext)
        )
      },

      async updateSyncState(nextSyncState = {}) {
        if (_.isMatch(this.syncState, nextSyncState)) {
          return Promise.resolve();
        }
        await this.reload(); // Fetch any recent syncState updates
        this.syncState = Object.assign(this.syncState, nextSyncState);
        return this.save();
      },

      toJSON() {
        return {
          id: `${this.id}`,
          account_id: this.accountId,
          object: 'folder',
          name: this.role,
          display_name: formatImapPath(this.name),
          sync_state: this.syncState,
        };
      },
    },
  });
};
