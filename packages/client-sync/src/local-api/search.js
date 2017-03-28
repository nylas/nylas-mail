const request = require('request');
const _ = require('underscore');
const Rx = require('rx-lite');
const {
  ExponentialBackoffScheduler,
  IMAPErrors,
  IMAPConnectionPool,
} = require('isomorphic-core')
const SyncProcessManager = require('../local-sync-worker/sync-process-manager')
const {
  Actions,
  SearchQueryParser,
  IMAPSearchQueryBackend,
} = require('nylas-exports')

const MAX_IMAP_TIMEOUT_ERRORS = 5;

const getThreadsForMessages = (db, messages, limit) => {
  if (messages.length === 0) {
    return Promise.resolve([]);
  }
  const {Message, Folder, Label, Thread, File} = db;
  const threadIds = _.uniq(messages.map((m) => m.threadId));
  return Thread.findAll({
    where: {id: threadIds},
    include: [
      {model: Folder},
      {model: Label},
      {
        model: Message,
        as: 'messages',
        attributes: _.without(Object.keys(Message.attributes), 'body'),
        include: [
          {model: Folder},
          {model: Label},
          {model: File},
        ],
      },
    ],
    limit: limit,
    order: [['lastMessageReceivedDate', 'DESC']],
  });
};

class SearchFolder {
  constructor(folder, criteria) {
    this.folder = folder;
    this.criteria = criteria;
  }

  description() {
    return 'IMAP folder search';
  }

  run(db, imap) {
    return imap.openBox(this.folder.name).then((box) => {
      return box.search(this.criteria);
    });
  }
}

class ImapSearchClient {
  constructor(account) {
    this.account = account;
    this._logger = global.Logger.forAccount(this.account);
    this._cancelled = false;
  }

  async _getFoldersForSearch(db, query) {
    const {Folder} = db;

    const folderNames = IMAPSearchQueryBackend.folderNamesForQuery(query);
    if (folderNames !== IMAPSearchQueryBackend.ALL_FOLDERS()) {
      if (folderNames.length === 0) {
        return [];
      }

      const result = await Folder.findAll({
        where: {
          accountId: this.account.id,
          name: folderNames,
        },
      });
      return result;
    }

    // We want to start the search with the 'inbox', 'sent' and 'archive'
    // folders, if they exist.
    const folders = await Folder.findAll({
      where: {
        accountId: this.account.id,
        role: ['inbox', 'sent', 'archive'],
      },
    });

    const accountFolders = await Folder.findAll({
      where: {
        accountId: this.account.id,
        id: {$notIn: folders.map((f) => f.id)},
      },
    });

    return folders.concat(accountFolders);
  }

  _getCriteriaForQuery(query, folder) {
    return IMAPSearchQueryBackend.compile(query, folder);
  }

  async _search(db, query) {
    const parsedQuery = SearchQueryParser.parse(query);
    const folders = await this._getFoldersForSearch(db, parsedQuery);
    let numTimeoutErrors = 0;
    return Rx.Observable.create(async (observer) => {
      const onConnected = async ([conn]) => {
        // Remove folders as we process them so we don't re-search previously
        // searched folders if there is an error later down the line.
        while (folders.length > 0) {
          const folder = folders[0];
          const criteria = this._getCriteriaForQuery(parsedQuery, folder);
          const uids = await this._searchFolder(conn, folder, criteria);
          folders.shift();
          if (uids.length > 0) {
            observer.onNext({uids, folder});
          }
        }
        observer.onCompleted();
      };

      const timeoutScheduler = new ExponentialBackoffScheduler({
        baseDelay: 15 * 1000,
        maxDelay: 5 * 60 * 1000,
      });

      const onTimeout = () => {
        numTimeoutErrors += 1;
        Actions.recordUserEvent('Timeout error in IMAP search', {
          accountId: this.account.id,
          provider: this.account.provider,
          socketTimeout: timeoutScheduler.currentDelay(),
          numTimeoutErrors,
        });
        timeoutScheduler.nextDelay();
      };

      while (numTimeoutErrors < MAX_IMAP_TIMEOUT_ERRORS) {
        try {
          await IMAPConnectionPool.withConnectionsForAccount(this.account, {
            desiredCount: 1,
            logger: this._logger,
            socketTimeout: timeoutScheduler.currentDelay(),
            onConnected,
          });
          break;
        } catch (err) {
          if (err instanceof IMAPErrors.IMAPConnectionTimeoutError) {
            onTimeout();
            continue;
          }
          throw err;
        }
      }
    });
  }

  _searchFolder(conn, folder, criteria) {
    return conn.runOperation(new SearchFolder(folder, criteria))
    .catch((error) => {
      this._logger.error(`Search error: ${error}`);
      return Promise.resolve([]);
    });
  }

  cancelSearchRequest() {
    this._cancelled = true;
  }

  async _cancelSyncbackTasks(db) {
    await db.SyncbackRequest.update(
      {status: 'CANCELLED'},
      {
        where: {
          type: "SyncUnknownUIDs",
          status: {$in: ["NEW", "INPROGRESS-RETRYABLE", "INPROGRESS-NOTRETRYABLE"]},
          accountId: this.account.id,
        },
      });
  }

  async searchThreads(db, query, limit) {
    const {Message} = db;
    const uidFolderStream = await this._search(db, query);
    // The first concatMap handles the fact that the async function returns promises
    // of the new observable streams.
    const messageListStreamStream = uidFolderStream.concatMap(async ({uids, folder}) => {
      let messages = await Message.findAll({
        attributes: ['id', 'threadId', 'folderImapUID'],
        where: {folderImapUID: uids},
      });

      let knownUids = new Set(messages.map(m => parseInt(m.folderImapUID, 10)));
      const unknownUids = uids.filter(uid => !knownUids.has(uid));

      if (unknownUids.length === 0 || this._cancelled) {
        return Rx.Observable.from([messages]);
      }
      // Sort into descending order so that we get the more recent messages sooner.
      unknownUids.sort((a, b) => b - a);

      await db.SyncbackRequest.create({
        type: "SyncUnknownUIDs",
        props: {folderId: folder.id, uids: unknownUids},
        accountId: this.account.id,
      })
      SyncProcessManager.wakeWorkerForAccount(this.account.id, {interrupt: true, reason: 'Sync unknown UIDs'});

      return Rx.Observable.create((observer) => {
        observer.onNext(messages);
        const findFn = async (remainingUids) => {
          if (this._cancelled) {
            await this._cancelSyncbackTasks(db);
            observer.onCompleted();
            return;
          }

          if (remainingUids.length === 0) {
            observer.onCompleted();
            return;
          }

          const newMessages = await Message.findAll({
            attributes: ['id', 'threadId', 'folderImapUID'],
            where: {folderImapUID: remainingUids},
          });
          messages = messages.concat(newMessages);
          if (newMessages.length > 0) {
            observer.onNext(newMessages);
          } 
          knownUids = new Set(messages.map(m => parseInt(m.folderImapUID, 10)));
          setTimeout(findFn, 1000, remainingUids.filter(uid => !knownUids.has(uid)));
        };
        findFn(unknownUids);
      });
    });
    // Now that we've unwrapped the promises with the previous concatMap, we
    // can flatten the observable into a stream of message lists.
    return messageListStreamStream.concatMap(messageListStream => {
      return messageListStream;
    }).map(messages => {
      return getThreadsForMessages(db, messages, limit);
    }).concatMap((threads) => {
      if (threads.length > 0) {
        return `${JSON.stringify(threads)}\n`;
      }
      return '\n';
    });
  }
}

class GmailSearchClient extends ImapSearchClient {
  async _getFoldersForSearch(db/* , query*/) {
    const allMail = await db.Folder.findOne({where: {role: 'all'}});
    return [allMail];
  }

  _getCriteriaForQuery(query/* , folder*/) {
    return [['X-GM-RAW', query]];
  }
}

module.exports.searchClientForAccount = (account) => {
  switch (account.provider) {
    case 'gmail': {
      return new GmailSearchClient(account);
    }
    case 'office365':
    case 'imap': {
      return new ImapSearchClient(account);
    }
    default: {
      throw new Error(`Unsupported provider for search endpoint: ${account.provider}`);
    }
  }
};
