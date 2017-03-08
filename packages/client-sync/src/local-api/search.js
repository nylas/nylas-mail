const request = require('request');
const _ = require('underscore');
const Rx = require('rx-lite');
const {IMAPConnectionPool} = require('isomorphic-core')
const SyncProcessManager = require('../local-sync-worker/sync-process-manager')
const {
  Actions,
  SearchQueryParser,
  IMAPSearchQueryBackend,
} = require('nylas-exports')

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

  async _getFoldersForSearch(db) {
    // We want to start the search with the 'inbox', 'sent' and 'archive'
    // folders, if they exist.
    const {Folder} = db;
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

  _getCriteriaForQuery(query) {
    const parsedQuery = SearchQueryParser.parse(query);
    return IMAPSearchQueryBackend.compile(parsedQuery);
  }

  async _search(db, query) {
    const folders = await this._getFoldersForSearch(db);
    const criteria = this._getCriteriaForQuery(query);
    let numTimeoutErrors = 0;
    let result = null;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this._logger,
      onConnected: async ([conn], done) => {
        result = Rx.Observable.create(async (observer) => {
          for (const folder of folders) {
            const uids = await this._searchFolder(conn, folder, criteria);
            if (uids.length > 0) {
              observer.onNext({uids, folder});
            }
          }
          observer.onCompleted();
          done();
        });
        return true;
      },
      onTimeout: (socketTimeout) => {
        numTimeoutErrors += 1;
        Actions.recordUserEvent('Timeout error in IMAP search', {
          accountId: this.account.id,
          provider: this.account.provider,
          socketTimeout,
          numTimeoutErrors,
        });
      },
    });
    return result;
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
          status: {$in: ["NEW", "INPROGRESS-RETRYABLE", "INPROGRESS-NONRETRYABLE"]},
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

      if (unknownUids.length === 0) {
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
  async _getFoldersForSearch(db) {
    const allMail = await db.Folder.findOne({where: {role: 'all'}});
    return [allMail];
  }

  _getCriteriaForQuery(query) {
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
