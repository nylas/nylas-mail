const crypto = require('crypto')
const {PromiseUtils, IMAPConnection} = require('isomorphic-core')
const {DatabaseTypes: {JSONArrayColumn}} = require('isomorphic-core');
const {Errors: {APIError}} = require('isomorphic-core')


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
    headerMessageId: { type: Sequelize.STRING, allowNull: true },
    gMsgId: { type: Sequelize.STRING, allowNull: true },
    gThrId: { type: Sequelize.STRING, allowNull: true },
    body: Sequelize.TEXT,
    subject: Sequelize.STRING(500),
    snippet: Sequelize.STRING(255),
    date: Sequelize.DATE,
    // TODO: We do not currently sync drafts with the remote. When we add
    // this feature, we need to be careful because this breaks the assumption
    // that messages, modulo their flags and folders/labels, are immutable.
    // Particularly, we will need to implement logic to make sure snippets
    // stay in sync with the current message body.
    isDraft: Sequelize.BOOLEAN,
    isSent: Sequelize.BOOLEAN,
    isSending: Sequelize.BOOLEAN,
    isProcessed: { type: Sequelize.BOOLEAN, defaultValue: false },
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
    processed: Sequelize.INTEGER,
    to: JSONArrayColumn('to'),
    from: JSONArrayColumn('from', {
      allowNull: true,
    }),
    cc: JSONArrayColumn('cc'),
    bcc: JSONArrayColumn('bcc'),
    replyTo: JSONArrayColumn('replyTo', {
      allowNull: true,
    }),
    folderImapUID: { type: Sequelize.STRING, allowNull: true},
    folderImapXGMLabels: { type: Sequelize.TEXT, allowNull: true},
    // Only used for reconstructing In-Reply-To/References when
    // placing newly sent messages in sent folder for generic IMAP/multi-send
    inReplyToLocalMessageId: { type: Sequelize.STRING(65), allowNull: true },
    // an array of IDs to Reference objects, specifying which order they
    // appeared on the original message (so we don't muck up the order when
    // sending replies, which could break other mail clients)
    referencesOrder: JSONArrayColumn('referencesOrder', { allowNull: true }),
    uploads: JSONArrayColumn('uploads', {
      validate: {
        uploadStructure(stringifiedArr) {
          const arr = JSON.parse(stringifiedArr);
          const requiredKeys = ['filename', 'targetPath', 'id']
          arr.forEach((upload) => {
            requiredKeys.forEach((key) => {
              if (!Object.prototype.hasOwnProperty.call(upload, key)) {
                throw new Error(`Upload must have '${key}' key.`)
              }
            })
          })
        },
      },
    }),
  }, {
    indexes: [
      {fields: ['folderId']},
      {fields: ['threadId']},
      {fields: ['gMsgId']}, // Use in `searchThreads`
      // TODO: when we add 2-way draft syncing, we're going to need this index
      // {fields: ['isDraft']},
      {fields: ['folderImapUID']}, // Use in `searchThreads`
    ],
    classMethods: {
      associate({Message, Folder, Label, File, Thread, MessageLabel, Reference, MessageReference}) {
        Message.belongsTo(Thread)
        Message.belongsTo(Folder)
        Message.belongsToMany(Label, {through: MessageLabel})
        Message.hasMany(File, {onDelete: 'cascade', hooks: true})
        Message.belongsToMany(Reference, {
          through: MessageReference,
          as: 'references',
        })
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
        return `<${id}@nylas-mail.nylas.com>`
      },

      // async findMultiSendMessage(db, messageId) {
      //   const message = await this.findById(messageId, {
      //     include: [
      //       {model: db.Folder},
      //     ],
      //   })
      //   if (!message) {
      //     throw new APIError(`Couldn't find multi-send message ${messageId}`, 400);
      //   }
      //   if (message.isSent || !message.isSending) {
      //     throw new APIError(`Message ${messageId} is not a multi-send message`, 400);
      //   }
      //   return message;
      // },

      requiredAssociationsForJSON({Folder, Label, File}) {
        return [
          {model: Folder},
          {model: Label},
          {model: File},
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
              // TODO: this can mangle the raw body of the email because it
              // does not respect the charset specified in the headers, which
              // MUST be decoded before you can figure out how to interpret the
              // body MIME bytes
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
          draft: this.isDraft,
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
          files: this.files ? this.files.map(f => f.toJSON()) : [],
          folder: this.folder ? this.folder.toJSON() : null,
          labels: this.labels ? this.labels.map(l => l.toJSON()) : [],
          imap_uid: this.folderImapUID,
          thread_id: this.threadId,
        };
      },
    },
  });
};
