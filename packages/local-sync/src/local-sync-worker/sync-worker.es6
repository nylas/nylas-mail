const _ = require('underscore')
const {
  IMAPConnection,
  IMAPErrors,
} = require('isomorphic-core');
const {
  Actions,
  APIError,
  NylasAPI,
  N1CloudAPI,
  NylasAPIRequest,
  Account: {SYNC_STATE_RUNNING, SYNC_STATE_AUTH_FAILED, SYNC_STATE_ERROR},
} = require('nylas-exports')
const Interruptible = require('../shared/interruptible')
const SyncMetricsReporter = require('./sync-metrics-reporter');
const SyncTaskFactory = require('./sync-task-factory');
const {getNewSyncbackTasks, markInProgressTasksAsFailed, runSyncbackTask} = require('./syncback-task-helpers');
const LocalSyncDeltaEmitter = require('./local-sync-delta-emitter').default


const SYNC_LOOP_INTERVAL_MS = 10 * 1000
const MAX_SOCKET_TIMEOUT_MS = 10 * 60 * 1000 // 10 min

class SyncWorker {
  constructor(account, db, parentManager) {
    this._db = db;
    this._manager = parentManager;
    this._conn = null;
    this._account = account;
    this._currentTask = null
    this._interruptible = new Interruptible()
    this._localDeltas = new LocalSyncDeltaEmitter(db, account.id)
    this._mailListenerConn = null

    this._startTime = Date.now()
    this._lastSyncTime = null
    this._logger = global.Logger.forAccount(account)
    this._interrupted = false
    this._syncInProgress = false
    this._stopped = false
    this._destroyed = false
    this._shouldIgnoreInboxFlagUpdates = false
    this._numRetries = 0;
    this._numTimeoutErrors = 0;
    this._socketTimeout = IMAPConnection.DefaultSocketTimeout;

    this._syncTimer = setTimeout(() => {
      // TODO this is currently a hack to keep N1's account in sync and notify of
      // sync errors. This should go away when we merge the databases
      Actions.updateAccount(this._account.id, {syncState: SYNC_STATE_RUNNING})
      this.syncNow({reason: 'Initial'});
    }, 0);

    // setup metrics collection. We do this in an isolated way by hooking onto
    // the database, because otherwise things get /crazy/ messy and I don't like
    // having counters and garbage everywhere.
    if (!account.firstSyncCompletion) {
      // TODO extract this into its own module, can use later on for exchange
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

  _getInboxFolder() {
    return this._db.Folder.find({where: {role: ['all', 'inbox']}})
  }

  async _cleanupOrphanMessages() {
    const {Message, Thread, Folder, Label} = this._db;
    const orphans = await Message.findAll({
      where: {
        folderId: null,
        isSent: {$not: true},
      },
    })
    const noFolderImapUID = await Message.findAll({
      where: {
        folderImapUID: null,
      },
    }).filter(m => Date.now() - m.date > 10 * 60 * 1000) // 10 min
    const affectedThreadIds = new Set();
    await Promise.map(orphans.concat(noFolderImapUID), (msg) => {
      affectedThreadIds.add(msg.threadId);
      return msg.destroy();
    });

    const affectedThreads = await Thread.findAll({
      where: {id: Array.from(affectedThreadIds)},
      include: [{model: Folder}, {model: Label}],
    });
    return Promise.map(affectedThreads, (thread) => {
      return thread.updateFromMessages({recompute: true, db: this._db})
    })
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
            accountId: this._account.emailAddress,
          },
        });

        const newCredentials = await req.run()
        this._account.setCredentials(newCredentials);
        await this._account.save();
        return newCredentials;
      }
      return null
    } catch (err) {
      if (err instanceof APIError) {
        const {statusCode} = err
        this._logger.error(`🔃  Unable to refresh access token. Got status code: ${statusCode}`, err);

        if (statusCode >= 500) {
          // Even though we don't consider 500s as permanent errors when
          // refreshing tokens, we want to report them
          NylasEnv.reportError(err)
        }
        const isNonPermanentError = (
          // If we got a 5xx error from the server, that means that something is wrong
          // on the Nylas API side. It could be a bad deploy, or a bug on Google's side.
          // In both cases, we've probably been alerted and are working on the issue,
          // so it makes sense to have the client retry.
          statusCode >= 500 ||
          !NylasAPI.PermanentErrorCodes.includes(statusCode)
        )
        if (isNonPermanentError) {
          throw new IMAPErrors.IMAPTransientAuthenticationError(`Server error when trying to refresh token.`);
        } else {
          throw new IMAPErrors.IMAPAuthenticationError(`Unable to refresh access token`);
        }
      }
      this._logger.error(`🔃  Unable to refresh access token.`, err);
      NylasEnv.reportError(err)
      throw new Error(`Unable to refresh access token, unknown error encountered`);
    }
  }

  _getIMAPSocketTimeout() {
    return Math.min(
      this._socketTimeout + (this._socketTimeout * (2 ** this._numTimeoutErrors)),
      MAX_SOCKET_TIMEOUT_MS
    )
  }

  async _ensureConnection() {
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
      throw new Error("_ensureConnection: There are no IMAP connection settings for this account.");
    }
    if (!credentials) {
      throw new Error("_ensureConnection: There are no IMAP connection credentials for this account.");
    }

    this._socketTimeout = this._getIMAPSocketTimeout()
    const conn = new IMAPConnection({
      db: this._db,
      settings: Object.assign({}, settings, credentials, {socketTimeout: this._socketTimeout}),
      logger: this._logger,
      account: this._account,
    });

    conn.on('queue-empty', () => {});

    this._conn = conn;
    return this._conn.connect();
  }

  async _ensureMailListenerConnection() {
    const newCredentials = await this._ensureAccessToken()

    if (!newCredentials && this._mailListenerConn) {
      // We already have a connection and we don't need to update the
      // credentials
      return this._mailListenerConn.connect();
    }

    const settings = this._account.connectionSettings;
    const credentials = newCredentials || this._account.decryptedCredentials();

    this._socketTimeout = this._getIMAPSocketTimeout()
    const conn = new IMAPConnection({
      db: this._db,
      settings: Object.assign({}, settings, credentials, {socketTimeout: this._socketTimeout}),
      logger: this._logger,
      account: this._account,
    });

    conn.on('mail', () => {
      this._onInboxUpdates(`You've got mail`);
    })
    conn.on('update', () => {
      // `update` events happen when messages receive flag updates on the inbox
      // (e.g. marking as unread or starred). We need to listen to that event for
      // when those updates are performed from another mail client, but ignore
      // them when they are caused from within N1.
      if (this._shouldIgnoreInboxFlagUpdates) { return; }
      this._onInboxUpdates(`There are flag updates on the inbox`);
    })

    this._mailListenerConn = conn;
    return this._mailListenerConn.connect();
  }

  async _listenForNewMail() {
    // Open the inbox folder on our dedicated mail listener connection to listen
    // to new mail events
    const inbox = await this._getInboxFolder();
    if (inbox && this._mailListenerConn) {
      await this._mailListenerConn.openBox(inbox.name)
    }
  }

  _onInboxUpdates = _.debounce((reason) => {
    this.syncNow({reason, interrupt: true});
  }, 100)

  _closeConnections() {
    if (this._conn) {
      this._conn.end();
    }
    if (this._mailListenerConn) {
      this._mailListenerConn.end()
    }
    this._conn = null
    this._mailListenerConn = null
  }


  async _getFoldersToSync() {
    const {Folder} = this._db;

    // Don't sync spam until everything else has been synced
    const allFolders = await Folder.findAll();
    const foldersExceptSpam = allFolders.filter((f) => f.role !== 'spam')
    const shouldIncludeSpam = foldersExceptSpam.every((f) => f.isSyncComplete())
    const foldersToSync = shouldIncludeSpam ? allFolders : foldersExceptSpam;

    // TODO make sure this order is correct/ unit tests!!
    const priority = ['inbox', 'all', 'sent', 'archive', 'drafts', 'trash', 'spam'].reverse();
    return foldersToSync.sort((a, b) =>
      (priority.indexOf(a.role) - priority.indexOf(b.role)) * -1
    )
  }

  async _onSyncError(error) {
    this._closeConnections()
    const errorJSON = error.toJSON()

    this._logger.error(`🔃  SyncWorker: Errored while syncing account`, error)

    if (error instanceof IMAPErrors.IMAPConnectionTimeoutError) {
      this._numTimeoutErrors += 1;
      Actions.recordUserEvent('Timeout error in sync loop', {
        accountId: this._account.id,
        provider: this._account.provider,
        socketTimeout: this._socketTimeout,
        numTimeoutErrors: this._numTimeoutErrors,
      })
    }

    // Don't save the error to the account if it was a network/retryable error
    // /and/ if we haven't retried too many times.
    if (error instanceof IMAPErrors.RetryableError) {
      this._numRetries += 1;
      return
    }

    error.message = `Error in sync loop: ${error.message}`
    NylasEnv.reportError(error)
    const isAuthError = error instanceof IMAPErrors.IMAPAuthenticationError
    const accountSyncState = isAuthError ? SYNC_STATE_AUTH_FAILED : SYNC_STATE_ERROR;
    // TODO this is currently a hack to keep N1's account in sync and notify of
    // sync errors. This should go away when we merge the databases
    Actions.updateAccount(this._account.id, {syncState: accountSyncState, syncError: errorJSON})

    this._account.syncError = errorJSON
    await this._account.save()
  }

  async _onSyncDidComplete() {
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

    this._logger.log(`🔃 🔚 took ${now - this._syncStart}ms`)
  }

  async _scheduleNextSync(error) {
    if (this._stopped) { return; }
    const {Folder} = this._db;

    const folders = await Folder.findAll();
    const moreToSync = folders.some((f) => !f.isSyncComplete())

    let interval;
    if (error != null) {
      if (error instanceof IMAPErrors.RetryableError) {
        // We do not want to retry over and over again when we get
        // network/retryable errors, for two reasons:
        // 1. most errors don't resolve immediately
        // 2. we don't want to be hammering the server in a synchronized way.
        const randomElement = (Math.floor(Math.random() * 20) + 1) * 1000;
        const exponentialDuration = 15000 * this._numRetries + randomElement;
        interval = Math.min(exponentialDuration, 120000 + randomElement);
      } else {
        // Encountered a permanent error
        // In this case we could do something fancier, but for now, just retry
        // with the normal sync loop interval
        interval = SYNC_LOOP_INTERVAL_MS
      }
    } else {
      // Continue syncing immediately if initial sync isn't done, or if the loop was
      // interrupted or a sync was requested
      const shouldSyncImmediately = (
        moreToSync ||
        this._interrupted
      )
      interval = shouldSyncImmediately ? 1 : SYNC_LOOP_INTERVAL_MS;
    }


    let reason = "Scheduled"
    if (error != null) {
      reason = `Sync errored`
    } else if (this._interrupted) {
      reason = `Sync interrupted and restarted. Interrupt reason: ${reason}`
    } else if (moreToSync) {
      reason = "More to sync"
    }

    const nextSyncIn = Math.max(1, this._lastSyncTime + interval - Date.now())
    this._logger.log(`🔃 🔜 in ${nextSyncIn}ms - Reason: ${reason}`)

    this._syncTimer = setTimeout(() => {
      this.syncNow({reason});
    }, nextSyncIn);
  }

  async _runTask(task) {
    this._currentTask = task
    await this._conn.runOperation(this._currentTask)
    this._currentTask = null
  }

  // This function is interruptible. See Interruptible
  async * _performSync() {
    yield this._account.update({syncError: null});
    yield this._ensureConnection();
    yield this._ensureMailListenerConnection();

    // Step 1: Mark all "INPROGRESS" tasks as failed.
    await markInProgressTasksAsFailed({db: this._db})
    yield // Yield to allow interruption

    // Step 2: Run any available syncback tasks
    // While running syncback tasks, we want to ignore `update` events on the
    // inbox.
    // `update` events happen when messages receive flag updates on the box,
    // (e.g. marking as unread or starred). We need to listen to that event for
    // when updates are performed from another mail client, but ignore
    // them when they are caused from within N1 to prevent unecessary interrupts
    const tasks = yield getNewSyncbackTasks({db: this._db, account: this._account})
    this._shouldIgnoreInboxFlagUpdates = true
    for (const task of tasks) {
      const {shouldRetry} = await runSyncbackTask({
        task,
        logger: this._logger,
        runTask: (t) => this._conn.runOperation(t),
      })
      if (shouldRetry) {
        this.syncNow({reason: 'Retrying syncback task', interrupt: true});
      }
      yield  // Yield to allow interruption
    }
    this._shouldIgnoreInboxFlagUpdates = false

    // Step 3: Fetch the folder list. We need to run this before syncing folders
    // because we need folders to sync!
    await this._runTask(SyncTaskFactory.create('FetchFolderList', {account: this._account}))
    yield  // Yield to allow interruption

    // Step 4: Listen to new mail. We need to do this after we've fetched the
    // folder list so we can correctly find the inbox folder on the very first
    // sync loop
    await this._listenForNewMail()
    yield  // Yield to allow interruption

    // Step 5: Sync each folder, sorted by inbox first
    // TODO prioritize syncing all of inbox first if there's a ton of folders (e.g. imap
    // accounts). If there are many folders, we would only sync the first n
    // messages in the inbox and not go back to it until we've done the same for
    // the rest of the folders, which would give the appearance of the inbox
    // syncing slowly. This should only be done during initial sync.
    // TODO Also consider using multiple imap connections, 1 for inbox, one for the
    // rest
    const sortedFolders = yield this._getFoldersToSync()
    for (const folder of sortedFolders) {
      await this._runTask(SyncTaskFactory.create('FetchMessagesInFolder', {account: this._account, folder}))
      yield  // Yield to allow interruption
    }
  }

  // Public API:

  async syncNow({reason, interrupt = false} = {}) {
    if (this._stopped) { return }
    if (this._syncInProgress) {
      if (interrupt) {
        this.interrupt({reason})
      }
      return;
    }

    this._syncStart = Date.now()
    clearTimeout(this._syncTimer);
    this._syncTimer = null;
    this._interrupted = false
    this._syncInProgress = true

    try {
      await this._account.reload();
    } catch (err) {
      this._logger.error(`🔃  SyncWorker: Account could not be loaded. Sync worker will exit.`, err)
      this._manager.removeWorkerForAccountId(this._account.id);
      return;
    }

    this._logger.log(`🔃 🆕 Reason: ${reason}`)
    let error;
    try {
      await this._interruptible.run(this._performSync, this)
      await this._cleanupOrphanMessages();
      await this._onSyncDidComplete();
      this._numRetries = 0;
      this._numTimeoutErrors = 0;
    } catch (err) {
      error = err
      await this._onSyncError(error);
    } finally {
      this._lastSyncTime = Date.now()
      this._syncInProgress = false
      await this._scheduleNextSync(error)
    }
  }

  async interrupt({reason = 'No reason'} = {}) {
    this._logger.log(`🔃 ✋ Interrupting sync! Reason: ${reason}`)
    const interruptPromises = [this._interruptible.interrupt()]
    if (this._currentTask) {
      interruptPromises.push(this._currentTask.interrupt())
    }
    await Promise.all(interruptPromises)
    this._interrupted = true
  }

  async stopSync() {
    this._stopped = true
    clearTimeout(this._syncTimer);
    this._syncTimer = null;
    if (this._syncInProgress) {
      return this.interrupt({reason: "Sync stopped"})
    }
    return Promise.resolve()
  }

  async cleanup() {
    await this.stopSync()
    this._destroyed = true;
    this._closeConnections()
  }
}

module.exports = SyncWorker;
