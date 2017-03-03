const request = require('request');
const _ = require('underscore');
const Rx = require('rx-lite');
const {IMAPConnectionPool} = require('isomorphic-core')
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
        result = Rx.Observable.create((observer) => {
          const chain = folders.reduce((acc, folder) => {
            return acc.then((uids) => {
              if (uids.length > 0) {
                observer.onNext(uids);
              }
              return this._searchFolder(conn, folder, criteria);
            });
          }, Promise.resolve([]));

          chain.then((uids) => {
            if (uids.length > 0) {
              observer.onNext(uids);
            }
            observer.onCompleted();
          }).finally(() => done());
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

  async searchThreads(db, query, limit) {
    const {Message} = db;
    return (await this._search(db, query)).flatMap((uids) => {
      return Message.findAll({
        attributes: ['id', 'threadId'],
        where: {folderImapUID: uids},
      });
    }).flatMap((messages) => {
      return getThreadsForMessages(db, messages, limit);
    }).flatMap((threads) => {
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
