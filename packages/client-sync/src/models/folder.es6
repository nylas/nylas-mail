import _ from 'underscore'
import crypto from 'crypto'
import {DatabaseTypes} from 'isomorphic-core'
import {formatImapPath} from '../shared/imap-paths-utils'

const {JSONColumn} = DatabaseTypes

export default (sequelize, Sequelize) => {
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

      syncProgress() {
        if (!this.syncState) {
          return {
            approxPercentComplete: 0,
            approxTotal: 0,
            oldestProcessedDate: new Date(),
          }
        }
        const {fetchedmax, fetchedmin, uidnext, minUID, oldestProcessedDate} = this.syncState;
        return {
          // based on % of uid space scanned, but space may be sparse
          approxPercentComplete: (+fetchedmax - +fetchedmin + 1) /
                                 (uidnext - Math.min(minUID, fetchedmin) + 1),
          approxTotal: uidnext,
          oldestProcessedDate: oldestProcessedDate,
        }
      },

      toJSON() {
        return {
          id: `${this.id}`,
          account_id: this.accountId,
          object: 'folder',
          name: this.role,
          display_name: formatImapPath(this.name),
          imap_name: this.name,
          sync_progress: this.syncProgress(),
          // intentionally overwrite any sync states stored in edgehill.db,
          // since it may contain long arrays and cause perf degredation
          // when serialized repeatedly
          sync_state: null,
        };
      },
    },
  });
};
