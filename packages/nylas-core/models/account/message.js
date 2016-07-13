const crypto = require('crypto');
const IMAPConnection = require('../../imap-connection')
const {JSONType, JSONARRAYType} = require('../../database-types');


module.exports = (sequelize, Sequelize) => {
  const Message = sequelize.define('message', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    headerMessageId: Sequelize.STRING,
    body: Sequelize.TEXT,
    headers: JSONType('headers'),
    subject: Sequelize.STRING(500),
    snippet: Sequelize.STRING(255),
    hash: Sequelize.STRING(65),
    date: Sequelize.DATE,
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
    processed: Sequelize.INTEGER,
    to: JSONARRAYType('to'),
    from: JSONARRAYType('from'),
    cc: JSONARRAYType('cc'),
    bcc: JSONARRAYType('bcc'),
    replyTo: JSONARRAYType('replyTo'),
    folderImapUID: { type: Sequelize.STRING, allowNull: true},
    folderImapXGMLabels: { type: Sequelize.TEXT, allowNull: true},
  }, {
    charset: 'utf8',
    indexes: [
      {
        unique: true,
        fields: ['hash'],
      },
    ],
    classMethods: {
      associate: ({Folder, Label, File, Thread}) => {
        Message.belongsTo(Thread)
        Message.belongsTo(Folder)
        Message.belongsToMany(Label, {through: 'message_labels'})
        Message.hasMany(File)
      },
      hashForHeaders: (headers) => {
        return crypto.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
    },
    instanceMethods: {
      setLabelsFromXGM(xGmLabels, {preloadedLabels} = {}) {
        if (!xGmLabels) {
          return Promise.resolve();
        }
        const labelNames = xGmLabels.filter(l => l[0] !== '\\')
        const labelRoles = xGmLabels.filter(l => l[0] === '\\').map(l => l.substr(1).toLowerCase())
        const Label = sequelize.models.label;

        let getLabels = null;
        if (preloadedLabels) {
          getLabels = Promise.resolve(preloadedLabels.filter(l => labelNames.includes(l.name) || labelRoles.includes(l.role)));
        } else {
          getLabels = Label.findAll({
            where: sequelize.or({name: labelNames}, {role: labelRoles}),
          })
        }

        this.folderImapXGMLabels = JSON.stringify(xGmLabels);

        return getLabels.then((labels) =>
          this.save().then(() =>
            this.setLabels(labels)
          )
        )
      },

      fetchRaw: function fetchRaw({account, db, logger}) {
        const settings = Object.assign({}, account.connectionSettings, account.decryptedCredentials())
        return Promise.props({
          folder: this.getFolder(),
          connection: IMAPConnection.connect({db, settings, logger}),
        })
        .then(({folder, connection}) => {
          return connection.openBox(folder.name)
          .then((imapBox) => imapBox.fetchMessage(this.folderImapUID))
          .then((message) => {
            if (message) {
              return Promise.resolve(`${message.headers}${message.body}`)
            }
            return Promise.reject(new Error(`Unable to fetch raw message for Message ${this.id}`))
          })
          .finally(() => connection.end())
        })
      },

      toJSON: function toJSON() {
        if (this.folder_id && !this.folder) {
          throw new Error("Message.toJSON called on a message where folder were not eagerly loaded.")
        }

        return {
          id: this.id,
          account_id: this.accountId,
          object: 'message',
          body: this.body,
          subject: this.subject,
          snippet: this.snippet,
          to: this.to,
          from: this.from,
          cc: this.cc,
          bcc: this.bcc,
          reply_to: this.replyTo,
          date: this.date.getTime() / 1000.0,
          unread: this.unread,
          starred: this.starred,
          folder: this.folder,
          thread_id: this.threadId,
        };
      },
    },
  });

  return Message;
};
