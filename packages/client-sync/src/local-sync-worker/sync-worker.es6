import _ from 'underscore'
import {
  IMAPErrors,
  SendmailClient,
  MetricsReporter,
  IMAPConnectionPool,
  ExponentialBackoffScheduler,
} from 'isomorphic-core';
import {
  Actions,
  Account,
  APIError,
  NylasAPI,
  N1CloudAPI,
  IdentityStore,
  NylasAPIRequest,
  BatteryStatusManager,
} from 'nylas-exports'
import Interruptible from '../shared/interruptible'
import SyncTaskFactory from './sync-task-factory';
import SyncbackTaskRunner from './syncback-task-runner'


const {SYNC_STATE_RUNNING, SYNC_STATE_AUTH_FAILED, SYNC_STATE_ERROR} = Account
const AC_SYNC_LOOP_INTERVAL_MS = 10 * 1000            // 10 sec
const BATTERY_SYNC_LOOP_INTERVAL_MS = 5 * 60 * 1000   //  5 min
const MAX_SYNC_BACKOFF_MS = 5 * 60 * 1000 // 5 min

class SyncWorker {
  constructor(account, db, parentManager) {
    this._db = db;
    this._manager = parentManager;
    this._conn = null;
    this._smtp = null;
    this._account = account;
    this._currentTask = null
    this._mailListenerConn = null
    this._interruptible = new Interruptible()
    this._logger = global.Logger.forAccount(account)

    this._startTime = Date.now()
    this._lastSyncTime = null
    this._interrupted = false
    this._syncInProgress = false
    this._stopped = false
    this._destroyed = false
    this._shouldIgnoreInboxFlagUpdates = false
    this._numTimeoutErrors = 0;
    this._requireTokenRefresh = false
    this._batchProcessedUids = new Map();
    this._latestOpenTimesByFolder = new Map();

    this._retryScheduler = new ExponentialBackoffScheduler({
      baseDelay: 15 * 1000,
      maxDelay: MAX_SYNC_BACKOFF_MS,
    })

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
        const identity = IdentityStore.identity()
        const nylasId = identity ? identity.id : null;
        if (seen === 0) {
          MetricsReporter.reportEvent({
            nylasId,
            type: 'imap',
            provider: account.provider,
            accountId: account.id,
            msecToFirstThread: (Date.now() - new Date(account.createdAt).getTime()),
          })
        }
        if (seen === 500) {
          MetricsReporter.reportEvent({
            nylasId,
            type: 'imap',
            provider: account.provider,
            accountId: account.id,
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

    const messagesWithoutFolder = await Message.findAll({
      attributes: ['id', 'threadId'],
      limit: 1000,
      where: {
        folderId: null,
        isSent: {$not: true},
      },
    })

    const messageIdsWithSendInProgress = await this._db.SyncbackRequest.findAll({
      limit: 100,
      where: {
        type: 'EnsureMessageInSentFolder',
        status: {$notIn: ['SUCCEEDED', 'FAILED']},
      },
    })
    .map(syncbackRequest => syncbackRequest.props.messageId)
    const messagesWithoutImapUID = await Message.findAll({
      attributes: ['id', 'threadId'],
      limit: 1000,
      where: {
        folderImapUID: null,
      },
    })
    // We don't want to remove messages that are currently being added to the
    // sent folder, which we know wont have a folderImapUID while that is
    // happening.
    .filter(m => !messageIdsWithSendInProgress.includes(m.id))
    .filter(m => Date.now() - m.date > 10 * 60 * 1000) // 10 min

    const messagesToRemove = [...messagesWithoutFolder, ...messagesWithoutImapUID]
    const affectedThreadIds = new Set();
    await Promise.map(messagesToRemove, (msg) => {
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
      return null;
    }

    try {
      const credentials = this._account.decryptedCredentials()
      if (!credentials) {
        throw new Error("ensureAccessToken: There are no IMAP connection credentials for this account.");
      }

      const currentUnixDate = Math.floor(Date.now() / 1000);
      if (this._requireTokenRefresh && (credentials.expiry_date > currentUnixDate)) {
        console.warn("ensureAccessToken: got Invalid Credentials from server but token is not expired");
      }
      // try to avoid tokens expiring during the sync loop
      const expiryDatePlusSlack = credentials.expiry_date - (5 * 60);
      if (this._requireTokenRefresh || (currentUnixDate > expiryDatePlusSlack)) {
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
        this._requireTokenRefresh = false
        return newCredentials;
      }
      return null
    } catch (err) {
      this._logger.warn(`🔃  Unable to refresh access token.`, err);
      if (err instanceof APIError) {
        const {statusCode} = err
        this._logger.error(`🔃  Unable to refresh access token. Got status code: ${statusCode}`, err);

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
          // sync worker is persistent across reauths, so need to clear this flag
          this._requireTokenRefresh = false
          throw new IMAPErrors.IMAPAuthenticationError(`Unable to refresh access token`);
        }
      }
      err.message = `Unknown error when refreshing access token: ${err.message}`
      const fingerprint = ["{{ default }}", "access token refresh", err.message];
      NylasEnv.reportError(err, {fingerprint,
        rateLimit: {
          ratePerHour: 30,
          key: `SyncError:RefreshToken:${err.message}`,
        },
      })
      throw err
    }
  }

  async _ensureSMTPConnection() {
    const newCredentials = await this._ensureAccessToken();
    if (!this._smtp || newCredentials) {
      this._smtp = new SendmailClient(this._account, this._logger)
    }
  }

  async _ensureIMAPConnection(conn) {
    if (this._conn === conn) {
      return;
    }

    conn.on('queue-empty', () => {});

    this._conn = conn;
    this._conn._db = this._db;
  }

  async _ensureIMAPMailListenerConnection(conn) {
    if (this._mailListenerConn === conn) {
      return;
    }

    this._mailListenerConn = conn;
    this._mailListenerConn._db = this._db;

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

  _clearConnections() {
    this._conn = null;
    this._mailListenerConn = null;
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
    try {
      this._clearConnections();
      this._logger.error(`🔃  SyncWorker: Errored while syncing account`, error)

      // Check if we encountered an expired token error.
      // We try to refresh Google OAuth2 access tokens in advance, but sometimes
      // it doesn't work (e.g. the token expires during the sync loop). In this
      // case, we need to immediately restart the sync loop & refresh the token.
      // We don't want to save the error to the account in case refreshing the
      // token fixes the issue.
      //
      // These error messages look like "Error: Invalid credentials (Failure)"
      const isExpiredTokenError = (
        this._account.provider === "gmail" &&
        error instanceof IMAPErrors.IMAPAuthenticationError &&
        /invalid credentials/i.test(error.message)
      )
      if (isExpiredTokenError) {
        this._requireTokenRefresh = true
        return
      }

      if (error instanceof IMAPErrors.IMAPConnectionTimeoutError) {
        this._numTimeoutErrors += 1;
        Actions.recordUserEvent('Timeout error in sync loop', {
          accountId: this._account.id,
          provider: this._account.provider,
          socketTimeout: this._retryScheduler.currentDelay(),
          numTimeoutErrors: this._numTimeoutErrors,
        });
      }

      // Check if we've encountered a retryable/network error.
      // If so, we don't want to save the error to the account, which will cause
      // a red box to show up.
      if (error instanceof IMAPErrors.RetryableError) {
        this._retryScheduler.nextDelay()
        return
      }
      // If we don't encounter consecutive RetryableErrors, reset the exponential
      // backoff
      this._retryScheduler.reset()

      // Update account error state
      const errorJSON = error.toJSON()
      const fingerprint = ["{{ default }}", "sync loop", error.message];
      NylasEnv.reportError(error, {fingerprint,
        rateLimit: {
          ratePerHour: 30,
          key: `SyncError:SyncLoop:${error.message}`,
        },
      });

      const isAuthError = error instanceof IMAPErrors.IMAPAuthenticationError
      const accountSyncState = isAuthError ? SYNC_STATE_AUTH_FAILED : SYNC_STATE_ERROR;
      // TODO this is currently a hack to keep N1's account in sync and notify of
      // sync errors. This should go away when we merge the databases
      Actions.updateAccount(this._account.id, {syncState: accountSyncState, syncError: errorJSON})

      this._account.syncError = errorJSON
      await this._account.save()
    } catch (err) {
      this._logger.error(`🔃  SyncWorker: Errored while handling error`, error)
      err.message = `Error while handling sync loop error: ${err.message}`
      NylasEnv.reportError(err)
    }
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
    let reason;
    let interval;
    try {
      if (this._stopped) { return; }
      const {Folder} = this._db;

      const folders = await Folder.findAll();
      const moreToSync = folders.some((f) => !f.isSyncComplete())

      if (error != null) {
        if (error instanceof IMAPErrors.RetryableError) {
          interval = this._retryScheduler.currentDelay();
        } else {
          interval = AC_SYNC_LOOP_INTERVAL_MS;
        }
      } else {
        const shouldSyncImmediately = (
          moreToSync ||
          this._interrupted ||
          this._requireTokenRefresh
        )
        if (shouldSyncImmediately) {
          interval = 1;
        } else if (BatteryStatusManager.isBatteryCharging()) {
          interval = AC_SYNC_LOOP_INTERVAL_MS;
        } else {
          interval = BATTERY_SYNC_LOOP_INTERVAL_MS;
        }
      }

      reason = 'Normal schedule'
      if (error != null) {
        reason = `Sync errored: ${error.message}`
      } else if (this._interrupted) {
        reason = `Sync interrupted and restarted. Interrupt reason: ${reason}`
      } else if (moreToSync) {
        reason = `More to sync`
      }
    } catch (err) {
      this._logger.error(`🔃  SyncWorker: Errored while scheduling next sync`, err)
      err.message = `Error while scheduling next sync: ${err.message}`
      NylasEnv.reportError(err)
      interval = AC_SYNC_LOOP_INTERVAL_MS
      reason = 'Errored while while scheduling next sync'
    } finally {
      const nextSyncIn = Math.max(1, this._lastSyncTime + interval - Date.now())
      this._logger.log(`🔃 🔜 in ${nextSyncIn}ms - Reason: ${reason}`)

      this._syncTimer = setTimeout(() => {
        this.syncNow({reason});
      }, nextSyncIn);
    }
  }

  async _runTask(task) {
    this._currentTask = task
    await this._conn.runOperation(this._currentTask, this)
    this._currentTask = null
  }

  // This function is interruptible. See Interruptible
  async * _performSync() {
    yield this._account.update({syncError: null});

    const syncbackTaskRunner = new SyncbackTaskRunner({
      db: this._db,
      imap: this._conn,
      smtp: this._smtp,
      logger: this._logger,
      account: this._account,
      syncWorker: this,
    })

    // Step 1: Mark all "INPROGRESS-NOTRETRYABLE" tasks as failed, and all
    // "INPROGRESS-RETRYABLE tasks as new
    await syncbackTaskRunner.updateLingeringTasksInProgress()
    yield // Yield to allow interruption

    // Step 2: Run any available syncback tasks
    // While running syncback tasks, we want to ignore `update` events on the
    // inbox.
    // `update` events happen when messages receive flag updates on the box,
    // (e.g. marking as unread or starred). We need to listen to that event for
    // when updates are performed from another mail client, but ignore
    // them when they are caused from within N1 to prevent unecessary interrupts
    const tasks = yield syncbackTaskRunner.getNewSyncbackTasks()
    this._shouldIgnoreInboxFlagUpdates = true
    for (const task of tasks) {
      await syncbackTaskRunner.runSyncbackTask(task)
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
      await this._ensureSMTPConnection();
      await IMAPConnectionPool.withConnectionsForAccount(this._account, {
        desiredCount: 2,
        logger: this._logger,
        socketTimeout: this._retryScheduler.currentDelay(),
        onConnected: async ([mainConn, listenerConn]) => {
          await this._ensureIMAPConnection(mainConn);
          await this._ensureIMAPMailListenerConnection(listenerConn);
          await this._interruptible.run(this._performSync, this)
        },
      });

      await this._cleanupOrphanMessages();
      await this._onSyncDidComplete();
      this._numTimeoutErrors = 0;
      this._retryScheduler.reset()
    } catch (err) {
      error = err
      await this._onSyncError(error);
    } finally {
      this._lastSyncTime = Date.now()
      this._syncInProgress = false
      this._clearConnections();
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
    this._clearConnections()
  }
}

SyncWorker.AC_SYNC_LOOP_INTERVAL_MS = AC_SYNC_LOOP_INTERVAL_MS
SyncWorker.BATTERY_SYNC_LOOP_INTERVAL_MS = BATTERY_SYNC_LOOP_INTERVAL_MS
SyncWorker.MAX_SYNC_BACKOFF_MS = MAX_SYNC_BACKOFF_MS

module.exports = SyncWorker;
