const {
  IMAPConnection,
  IMAPErrors,
  PromiseUtils,
} = require('isomorphic-core');
const {
  Actions,
  N1CloudAPI,
  NylasAPIRequest,
  Account: {SYNC_STATE_RUNNING, SYNC_STATE_AUTH_FAILED, SYNC_STATE_ERROR},
} = require('nylas-exports')
const LocalDatabaseConnector = require('../shared/local-database-connector')
const FetchFolderList = require('./imap/fetch-folder-list')
const FetchMessagesInFolder = require('./imap/fetch-messages-in-folder')
const SyncbackTaskFactory = require('./syncback-task-factory')
const SyncMetricsReporter = require('./sync-metrics-reporter');
const LocalSyncDeltaEmitter = require('./local-sync-delta-emitter').default

const RESTART_THRESHOLD = 10

class SyncWorker {
  constructor(account, db, parentManager) {
    this._db = db;
    this._manager = parentManager;
    this._conn = null;
    this._account = account;
    this._startTime = Date.now();
    this._lastSyncTime = null;
    this._logger = global.Logger.forAccount(account)
    this._interrupted = false
    this._syncInProgress = false
    this._syncAttemptsWhileInProgress = 0
    this._localDeltas = new LocalSyncDeltaEmitter(db, account.id)

    this._destroyed = false;
    this._syncTimer = setTimeout(() => {
      this.syncNow({reason: 'Initial'});
    }, 0);

    // setup metrics collection. We do this in an isolated way by hooking onto
    // the database, because otherwise things get /crazy/ messy and I don't like
    // having counters and garbage everywhere.
    if (!account.firstSyncCompletion) {
      // TODO extract this into its own module, can use later on for exchange
      this._logger.info("This is initial sync. Setting up metrics collection!");

      let seen = 0;
      db.Thread.addHook('afterCreate', 'metricsCollection', () => {
        if (seen === 0) {
          SyncMetricsReporter.reportEvent({
            type: 'imap',
            emailAddress: account.emailAddress,
            msecToFirstThread: (Date.now() - new Date(account.createdAt).getTime()),
          })
        }
        if (seen === 500) {
          SyncMetricsReporter.reportEvent({
            type: 'imap',
            emailAddress: account.emailAddress,
            msecToFirst500Threads: (Date.now() - new Date(account.createdAt).getTime()),
          })
        }

        if (seen > 500) {
          db.Thread.removeHook('afterCreate', 'metricsCollection')
        }
        seen += 1;
      });
    }
  }

  _onConnectionIdleUpdate() {
    this.syncNow({reason: "You've got mail!"});
  }

  _getIdleFolder() {
    return this._db.Folder.find({where: {role: ['all', 'inbox']}})
  }

  async _getAccount() {
    const {Account} = await LocalDatabaseConnector.forShared()
    Account.find({where: {id: this._account.id}})
  }

  /**
   * Returns a list of at most 100 Syncback requests, sorted by creation date
   * (older first) and by how they affect message IMAP uids.
   *
   * We want to make sure that we run the tasks that affect IMAP uids last, and
   * that we don't  run 2 tasks that will affect the same set of UIDS together,
   * i.e. without running a sync loop in between them.
   *
   * For example, if there's a task to change the labels of a message, and also
   * a task to move that message to another folder, we need to run the label
   * change /first/, otherwise the message would be moved and it would receive a
   * new IMAP uid, and then attempting to change labels with an old uid would
   * fail.
   */
  async _getNewSyncbackTasks() {
    const {SyncbackRequest, Message} = this._db;
    const where = {
      limit: 100,
      where: {status: "NEW"},
      order: [['createdAt', 'ASC']],
    };

    const tasks = await SyncbackRequest.findAll(where)
    .map((req) => SyncbackTaskFactory.create(this._account, req))

    if (tasks.length === 0) { return [] }

    const tasksToProcess = tasks.filter(t => !t.affectsImapMessageUIDs())
    const tasksAffectingUIDs = tasks.filter(t => t.affectsImapMessageUIDs())

    const changeFolderTasks = tasksAffectingUIDs.filter(t =>
      t.description() === 'RenameFolder' || t.description() === 'DeleteFolder'
    )
    if (changeFolderTasks.length > 0) {
      // If we are renaming or deleting folders, those are the only tasks we
      // want to process before executing any other tasks that may change uids.
      // These operations may not change the uids of their messages, but we
      // can't guarantee it, so to make sure, we will just run these.
      const affectedFolderIds = new Set()
      changeFolderTasks.forEach((task) => {
        const {props: {folderId}} = task.syncbackRequestObject()
        if (folderId && !affectedFolderIds.has(folderId)) {
          tasksToProcess.push(task)
          affectedFolderIds.add(folderId)
        }
      })
      return tasksToProcess
    }

    // Otherwise, make sure that we don't process more than 1 task that will affect
    // the UID of the same message
    const affectedMessageIds = new Set()
    for (const task of tasksAffectingUIDs) {
      const {props: {messageId, threadId}} = task.syncbackRequestObject()
      if (messageId) {
        if (!affectedMessageIds.has(messageId)) {
          tasksToProcess.push(task)
          affectedMessageIds.add(messageId)
        }
      } else if (threadId) {
        const messageIds = await Message.findAll({where: {threadId}}).map(m => m.id)
        const shouldIncludeTask = messageIds.every(id => !affectedMessageIds.has(id))
        if (shouldIncludeTask) {
          tasksToProcess.push(task)
          messageIds.forEach(id => affectedMessageIds.add(id))
        }
      }
    }
    return tasksToProcess
  }

  async _getFoldersToSync() {
    const {Folder} = this._db;

    // TODO make sure this order is correct/ unit tests!!
    const folders = await Folder.findAll();
    const priority = ['inbox', 'all', 'drafts', 'sent', 'trash', 'spam'].reverse();
    return folders.sort((a, b) =>
      (priority.indexOf(a.role) - priority.indexOf(b.role)) * -1
    )
  }

  async _ensureAccessToken() {
    if (this._account.provider !== 'gmail') {
      return null
    }

    try {
      const credentials = this._account.decryptedCredentials()
      if (!credentials) {
        throw new Error("ensureAccessToken: There are no IMAP connection credentials for this account.");
      }

      const currentUnixDate = Math.floor(Date.now() / 1000);
      if (currentUnixDate > credentials.expiry_date) {
        const req = new NylasAPIRequest({
          api: N1CloudAPI,
          options: {
            path: `/auth/gmail/refresh`,
            method: 'POST',
            accountId: this._account.id,
          },
        });

        const newCredentials = await req.run()
        this._account.setCredentials(newCredentials);
        await this._account.save()
        return newCredentials
      }
      return null
    } catch (err) {
      this._logger.error(err, 'Unable to refresh access token')
      throw new IMAPErrors.IMAPAuthenticationError(`Unable to refresh access token`)
    }
  }

  async ensureConnection() {
    const newCredentials = await this._ensureAccessToken()

    if (!newCredentials && this._conn) {
      // We already have a connection and we don't need to update the
      // credentials
      return this._conn.connect();
    }

    if (newCredentials) {
      this._logger.info("Refreshed and updated access token.");
    }

    const settings = this._account.connectionSettings;
    const credentials = newCredentials || this._account.decryptedCredentials();

    if (!settings || !settings.imap_host) {
      throw new Error("ensureConnection: There are no IMAP connection settings for this account.");
    }
    if (!credentials) {
      throw new Error("ensureConnection: There are no IMAP connection credentials for this account.");
    }

    const conn = new IMAPConnection({
      db: this._db,
      settings: Object.assign({}, settings, credentials),
      logger: this._logger,
      account: this._account,
    });

    conn.on('mail', () => {
      this._onConnectionIdleUpdate();
    })
    conn.on('update', () => {
      this._onConnectionIdleUpdate();
    })
    conn.on('queue-empty', () => {});

    this._conn = conn;
    return this._conn.connect();
  }

  cleanup() {
    clearTimeout(this._syncTimer);
    this._syncTimer = null;
    this._destroyed = true;
    this.closeConnection()
  }

  closeConnection() {
    if (this._conn) {
      this._conn.end();
    }
    this._conn = null
  }

  async runNewSyncbackTasks() {
    const tasks = await this._getNewSyncbackTasks()
    if (tasks.length === 0) { return Promise.resolve() }
    return PromiseUtils.each(tasks, (task) => this.runSyncbackTask(task));
  }

  async runSyncbackTask(task) {
    const syncbackRequest = task.syncbackRequestObject();
    console.log(`🔃 📤 ${syncbackRequest.type}`, syncbackRequest.props)
    try {
      const responseJSON = await this._conn.runOperation(task);
      syncbackRequest.status = "SUCCEEDED";
      syncbackRequest.responseJSON = responseJSON || {};
    } catch (error) {
      syncbackRequest.error = error;
      syncbackRequest.status = "FAILED";
      this._logger.error(error, {syncbackRequest: syncbackRequest.toJSON()}, `${task.description()} failed`);
    } finally {
      await syncbackRequest.save();
    }
  }

  async syncNow({reason, priority = 1} = {}) {
    if (this._syncInProgress) {
      this._syncAttemptsWhileInProgress += priority
      if (this._syncAttemptsWhileInProgress >= RESTART_THRESHOLD) {
        this._interrupted = true
      }
      return;
    }

    this._syncStart = Date.now()
    clearTimeout(this._syncTimer);
    this._syncTimer = null;
    this._interrupted = false
    this._syncAttemptsWhileInProgress = 0
    this._syncInProgress = true

    try {
      await this._account.reload();
    } catch (err) {
      this._logger.error({err}, `SyncWorker: Account could not be loaded. Sync worker will exit.`)
      this._manager.removeWorkerForAccountId(this._account.id);
      return;
    }

    console.log(`🔃 🆕 reason: ${reason}`)
    // this._logger.info({reason}, `SyncWorker: Account sync started`)

    try {
      await this._account.update({syncError: null});
      await this.ensureConnection();
      await this.runNewSyncbackTasks();
      await this._conn.runOperation(new FetchFolderList(this._account, this._logger));

      // TODO prioritize syncing all of inbox first if there's a ton of folders (e.g. imap
      // accounts). If there are many folders, we would only sync the first n
      // messages in the inbox and not go back to it until we've done the same for
      // the rest of the folders, which would give the appearance of the inbox
      // syncing slowly. This should only be done during initial sync.
      // TODO Also consider using multiple imap connections, 1 for inbox, one for the
      // rest
      const sortedFolders = await this._getFoldersToSync()
      const {folderSyncOptions} = this._account.syncPolicy;
      for (const folder of sortedFolders) {
        if (this._interrupted) {
          break;
        }
        await this._conn.runOperation(new FetchMessagesInFolder(folder, folderSyncOptions, this._logger))
      }

      await this.cleanupOrphanMessages();
      await this.onSyncDidComplete();
    } catch (error) {
      await this.onSyncError(error);
    } finally {
      this._lastSyncTime = Date.now()
      this._syncInProgress = false
      await this.scheduleNextSync()
    }
  }

  async cleanupOrphanMessages() {
    const orphans = await this._db.Message.findAll({
      where: {
        folderId: null,
        isSent: {$not: true},
        isSending: {$not: true},
      },
    })
    return Promise.map(orphans, (msg) => msg.destroy());
  }

  onSyncError(error) {
    this.closeConnection()

    this._logger.error(error, `SyncWorker: Error while syncing account`)

    // Continue to retry if it was a network error
    if (error instanceof IMAPErrors.RetryableError) {
      return Promise.resolve()
    }

    const isAuthError = error instanceof IMAPErrors.IMAPAuthenticationError
    const errorJSON = error.toJSON()
    const accountSyncState = isAuthError ? SYNC_STATE_AUTH_FAILED : SYNC_STATE_ERROR;
    // TODO this is currently a hack to keep N1's account in sync and notify of
    // sync errors. This should go away when we merge the databases
    Actions.updateAccount(this._account.id, {syncState: accountSyncState, syncError: errorJSON})

    this._account.syncError = errorJSON
    return this._account.save()
  }

  async onSyncDidComplete() {
    const now = Date.now();

    // Save metrics to the account object
    if (!this._account.firstSyncCompletion) {
      this._account.firstSyncCompletion = now;
    }

    const syncGraphTimeLength = 60 * 30; // 30 minutes, should be the same as SyncGraph.config.timeLength
    let lastSyncCompletions = [].concat(this._account.lastSyncCompletions);
    lastSyncCompletions = [now, ...lastSyncCompletions];
    while (now - lastSyncCompletions[lastSyncCompletions.length - 1] > 1000 * syncGraphTimeLength) {
      lastSyncCompletions.pop();
    }

    // TODO this is currently a hack to keep N1's account in sync and notify of
    // sync errors. This should go away when we merge the databases
    Actions.updateAccount(this._account.id, {syncState: SYNC_STATE_RUNNING})

    this._account.lastSyncCompletions = lastSyncCompletions;
    await this._account.save();

    console.log(`🔃 🔚 took ${now - this._syncStart}ms`)
    // this._logger.info('Syncworker: Completed sync cycle');

    // Start idling on the inbox
    const idleFolder = await this._getIdleFolder();
    await this._conn.openBox(idleFolder.name);
    // this._logger.info('SyncWorker: Idling on inbox folder');
  }

  async scheduleNextSync() {
    const {intervals} = this._account.syncPolicy;
    const {Folder} = this._db;

    const folders = await Folder.findAll();
    const moreToSync = folders.some((f) => !f.isSyncComplete())

    // Continue syncing if initial sync isn't done, or if the loop was
    // interrupted or a sync was requested
    const shouldSyncImmediately = (
      moreToSync ||
      this._interrupted ||
      this._syncAttemptsWhileInProgress > 0
    )

    let reason = "Idle scheduled"
    if (moreToSync) {
      reason = "More to sync"
    } else if (this._interrupted) {
      reason = "Sync interrupted by high priority task"
    } else if (this._syncAttemptsWhileInProgress > 0) {
      reason = "Sync requested while in progress"
    }
    const interval = shouldSyncImmediately ? 1 : intervals.active;
    const nextSyncIn = Math.max(1, this._lastSyncTime + interval - Date.now())

    // this._logger.info({
    //   moreToSync,
    //   shouldSyncImmediately,
    //   interrupted: this._interrupted,
    //   nextSyncStartingIn: `${nextSyncIn}ms`,
    //   syncAttemptsWhileInProgress: this._syncAttemptsWhileInProgress,
    // }, `SyncWorker: Scheduling next sync iteration`)
    console.log(`🔃 🔜 in ${nextSyncIn}ms`)

    this._syncTimer = setTimeout(() => {
      this.syncNow({reason});
    }, nextSyncIn);
  }
}

module.exports = SyncWorker;
