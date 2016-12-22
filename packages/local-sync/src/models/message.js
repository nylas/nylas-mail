const crypto = require('crypto')
const striptags = require('striptags');
const {PromiseUtils, IMAPConnection} = require('isomorphic-core')
const {DatabaseTypes: {JSONColumn, JSONArrayColumn}} = require('isomorphic-core');
const {Errors: {APIError}} = require('isomorphic-core')


const SNIPPET_LENGTH = 191;

function getLengthValidator(fieldName, min, max) {
  return (stringifiedArr) => {
    const arr = JSON.parse(stringifiedArr);
    if ((arr.length < min) || (arr.length > max)) {
      throw new Error(`Value for ${fieldName} must have a length in range [${min}-${max}]. Value: ${stringifiedArr}`);
    }
  };
}

function validateRecipientsPresent(message) {
  if (message.getRecipients().length === 0) {
    throw new APIError(`No recipients specified`, 400);
  }
}

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('message', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    headerMessageId: Sequelize.STRING,
    gMsgId: { type: Sequelize.STRING, allowNull: true },
    body: Sequelize.TEXT('long'),
    headers: JSONColumn('headers'),
    subject: Sequelize.STRING(500),
    snippet: Sequelize.STRING(255),
    date: Sequelize.DATE,
    isDraft: Sequelize.BOOLEAN,
    isSent: Sequelize.BOOLEAN,
    isSending: Sequelize.BOOLEAN,
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
    processed: Sequelize.INTEGER,
    to: JSONArrayColumn('to'),
    from: JSONArrayColumn('from', {
      validate: {validateArrayLength1: getLengthValidator('Message.from', 1, 1)},
      allowNull: true,
    }),
    cc: JSONArrayColumn('cc'),
    bcc: JSONArrayColumn('bcc'),
    replyTo: JSONArrayColumn('replyTo', {
      validate: {validateArrayLength1: getLengthValidator('Message.replyTo', 0, 1)},
      allowNull: true,
    }),
    inReplyTo: { type: Sequelize.STRING, allowNull: true},
    references: JSONArrayColumn('references'),
    folderImapUID: { type: Sequelize.STRING, allowNull: true},
    folderImapXGMLabels: { type: Sequelize.TEXT, allowNull: true},
    uploads: JSONArrayColumn('uploads', {
      validate: {
        uploadStructure(stringifiedArr) {
          const arr = JSON.parse(stringifiedArr);
          const requiredKeys = ['filename', 'targetPath', 'id']
          arr.forEach((upload) => {
            requiredKeys.forEach((key) => {
              if (!upload.hasOwnPropery(key)) {
                throw new Error(`Upload must have '${key}' key.`)
              }
            })
          })
        },
      },
    }),
  }, {
    indexes: [
      {
        unique: true,
        fields: ['id'],
      },
      {
        unique: false,
        fields: ['folderId'],
      },
      {
        unique: false,
        fields: ['threadId'],
      },
    ],
    hooks: {
      beforeUpdate(message) {
        // Update the snippet if the body has changed
        if (!message.changed('body')) { return; }

        const plainText = striptags(message.body);
        // consolidate whitespace groups into single spaces and then truncate
        message.snippet = plainText.split(/\s+/).join(" ").substring(0, SNIPPET_LENGTH)
      },
    },
    classMethods: {
      associate({Message, Folder, Label, File, Thread, MessageLabel}) {
        Message.belongsTo(Thread)
        Message.belongsTo(Folder)
        Message.belongsToMany(Label, {through: MessageLabel})
        Message.hasMany(File)
      },

      hash({from = [], to = [], cc = [], bcc = [], date = '', subject = '', headerMessageId = ''} = {}) {
        const emails = from.concat(to, cc, bcc)
        .map(participant => participant.email)
        .sort();
        const participants = emails.join('')
        const data = `${date}-${subject}-${participants}-${headerMessageId}`;
        return crypto.createHash('sha256').update(data, 'utf8').digest('hex');
      },

      buildHeaderMessageId(id) {
        return `<${id}@mailer.nylas.com>`
      },

      async findMultiSendMessage(db, messageId) {
        const message = await this.findById(messageId, {
          include: [
            {model: db.Folder},
          ],
        })
        if (!message) {
          throw new APIError(`Couldn't find multi-send message ${messageId}`, 400);
        }
        if (message.isSent || !message.isSending) {
          throw new APIError(`Message ${messageId} is not a multi-send message`, 400);
        }
        return message;
      },

      requiredAssociationsForJSON({Folder, Label}) {
        return [
          {model: Folder},
          {model: Label},
        ]
      },
    },
    instanceMethods: {
      getRecipients() {
        const {to, cc, bcc} = this;
        return [].concat(to, cc, bcc);
      },

      async setLabelsFromXGM(xGmLabels, {Label, preloadedLabels} = {}) {
        this.folderImapXGMLabels = JSON.stringify(xGmLabels);
        const labels = await Label.findXGMLabels(xGmLabels, {preloadedLabels})
        return this.setLabels(labels);
      },

      setIsSent(val) {
        if (val) {
          this.isDraft = false
          this.isSending = false
        }
        this.isSent = val
      },

      setIsSending(val) {
        if (val) {
          if (this.isSent || this.isSending) {
            throw new APIError('Cannot mark a sent message as sending', 400);
          }
          validateRecipientsPresent(this);
          this.isDraft = false;
        }
        this.isSending = val
      },

      fetchRaw({account, db, logger}) {
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
              return Promise.resolve(`${message.headers}${message.parts.TEXT}`)
            }
            return Promise.reject(new Error(`Unable to fetch raw message for Message ${this.id}`))
          })
          .finally(() => connection.end())
        })
      },

      toJSON() {
        if (this.folderId && !this.folder) {
          throw new Error("Message.toJSON called on a message where folder was not eagerly loaded.")
        }

        // When we request messages as a sub-object of a thread, we only
        // request the `id` field from the database. We still toJSON the
        // Message though and need to protect `this.date` from null
        // errors.
        // Folders and labels can be null if the message is sending!
        return {
          id: this.id,
          account_id: this.accountId,
          object: this.isDraft ? 'draft' : 'message',
          body: this.body,
          subject: this.subject,
          snippet: this.snippet,
          to: this.to,
          from: this.from,
          cc: this.cc,
          bcc: this.bcc,
          reply_to: this.replyTo,
          date: this.date ? this.date.getTime() / 1000.0 : null,
          unread: this.unread,
          starred: this.starred,
          folder: this.folder ? this.folder.toJSON() : null,
          labels: this.labels ? this.labels.map(l => l.toJSON()) : null,
          thread_id: this.threadId,
        };
      },
    },
  });
};
