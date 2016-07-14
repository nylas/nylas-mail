const crypto = require('crypto');
const PromiseUtils = require('../../promise-utils')
const IMAPConnection = require('../../imap-connection')
const {JSONType, JSONARRAYType} = require('../../database-types');


module.exports = (sequelize, Sequelize) => {
  return sequelize.define('message', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    headerMessageId: Sequelize.STRING,
    body: Sequelize.TEXT('long'),
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
    indexes: [
      {
        unique: true,
        fields: ['hash'],
      },
    ],
    classMethods: {
      associate: ({Message, Folder, Label, File, Thread, MessageLabel}) => {
        Message.belongsTo(Thread)
        Message.belongsTo(Folder)
        Message.belongsToMany(Label, {through: MessageLabel})
        Message.hasMany(File)
      },
      hashForHeaders: (headers) => {
        return crypto.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
    },
    instanceMethods: {
      setLabelsFromXGM(xGmLabels, {Label, preloadedLabels} = {}) {
        if (!xGmLabels) {
          return Promise.resolve();
        }
        const labelNames = xGmLabels.filter(l => l[0] !== '\\')
        const labelRoles = xGmLabels.filter(l => l[0] === '\\').map(l => l.substr(1).toLowerCase())

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
        return PromiseUtils.props({
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
        const json = Object.assign({object: 'message'}, this.dataValues)
        if (json.date) {
          json.date = json.date.getTime() / 1000.0
        }
        return json
      },
    },
  });
};
