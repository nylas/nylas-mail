const _ = require('underscore');
const cryptography = require('crypto');
const {PromiseUtils, IMAPConnection} = require('isomorphic-core')
const {DatabaseTypes: {buildJSONColumnOptions, buildJSONARRAYColumnOptions}} = require('isomorphic-core');
const striptags = require('striptags');
const SendingUtils = require('../local-api/sending-utils');

const SNIPPET_LENGTH = 191;

const getValidateArrayLength = (fieldName, min, max) => {
  return (stringifiedArr) => {
    const arr = JSON.parse(stringifiedArr);
    if ((arr.length < min) || (arr.length > max)) {
      throw new Error(`Value for ${fieldName} must have a length in range [${min}-${max}]. Value: ${stringifiedArr}`);
    }
  };
}

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('message', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    headerMessageId: Sequelize.STRING,
    body: Sequelize.TEXT('long'),
    headers: buildJSONColumnOptions('headers'),
    subject: Sequelize.STRING(500),
    snippet: Sequelize.STRING(255),
    date: Sequelize.DATE,
    isDraft: Sequelize.BOOLEAN,
    isSent: {
      type: Sequelize.BOOLEAN,
      set: async function set(val) {
        if (val) {
          this.isDraft = false;
          this.date = (new Date()).getTime();
          const thread = await this.getThread();
          await thread.updateFromMessage(this)
        }
        this.setDataValue('isSent', val);
      },
    },
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
    processed: Sequelize.INTEGER,
    to: buildJSONARRAYColumnOptions('to'),
    from: Object.assign(buildJSONARRAYColumnOptions('from'), {
      validate: {validateArrayLength1: getValidateArrayLength('Message.from', 1, 1)},
      allowNull: true,
    }),
    cc: buildJSONARRAYColumnOptions('cc'),
    bcc: buildJSONARRAYColumnOptions('bcc'),
    replyTo: Object.assign(buildJSONARRAYColumnOptions('replyTo'), {
      validate: {validateArrayLength1: getValidateArrayLength('Message.replyTo', 0, 1)},
      allowNull: true,
    }),
    inReplyTo: { type: Sequelize.STRING, allowNull: true},
    references: buildJSONARRAYColumnOptions('references'),
    folderImapUID: { type: Sequelize.STRING, allowNull: true},
    folderImapXGMLabels: { type: Sequelize.TEXT, allowNull: true},
    isSending: {
      type: Sequelize.BOOLEAN,
      set: function set(val) {
        if (val) {
          if (this.isSent) {
            throw new Error("Cannot mark a sent message as sending");
          }
          SendingUtils.validateRecipientsPresent(this);
          this.isDraft = false;
          this.regenerateHeaderMessageId();
        }
        this.setDataValue('isSending', val);
      },
    },
    uploads: Object.assign(buildJSONARRAYColumnOptions('testFiles'), {
      validate: {
        uploadStructure: function uploadStructure(stringifiedArr) {
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
    ],
    classMethods: {
      associate({Message, Folder, Label, File, Thread, MessageLabel}) {
        Message.belongsTo(Thread)
        Message.belongsTo(Folder)
        Message.belongsToMany(Label, {through: MessageLabel})
        Message.hasMany(File)
      },

      hashForHeaders(headers) {
        return cryptography.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
      fromJSON(data) {
        // TODO: events, metadata??
        return this.build({
          accountId: data.account_id,
          from: data.from,
          to: data.to,
          cc: data.cc,
          bcc: data.bcc,
          replyTo: data.reply_to,
          subject: data.subject,
          body: data.body,
          unread: true,
          isDraft: data.is_draft,
          isSent: false,
          version: 0,
          date: data.date,
          id: data.id,
          uploads: data.uploads,
        });
      },
      async associateFromJSON(data, db) {
        const message = this.fromJSON(data);
        const {Thread, Message} = db;

        let replyToThread;
        let replyToMessage;
        if (data.thread_id != null) {
          replyToThread = await Thread.find({
            where: {id: data.thread_id},
            include: [{
              model: Message,
              as: 'messages',
              attributes: _.without(Object.keys(Message.attributes), 'body'),
            }],
          });
        }
        if (data.reply_to_message_id != null) {
          replyToMessage = await Message.findById(data.reply_to_message_id);
        }

        if (replyToThread && replyToMessage) {
          if (!replyToThread.messages.find((msg) => msg.id === replyToMessage.id)) {
            throw new SendingUtils.HTTPError(
              `Message ${replyToMessage.id} is not in thread ${replyToThread.id}`,
              400
            )
          }
        }

        let thread;
        if (replyToMessage) {
          SendingUtils.setReplyHeaders(message, replyToMessage);
          thread = await message.getThread();
        } else if (replyToThread) {
          thread = replyToThread;
          const previousMessages = thread.messages.filter(msg => !msg.isDraft);
          if (previousMessages.length > 0) {
            const lastMessage = previousMessages[previousMessages.length - 1]
            SendingUtils.setReplyHeaders(message, lastMessage);
          }
        } else {
          thread = Thread.build({
            accountId: message.accountId,
            subject: message.subject,
            firstMessageDate: message.date,
            lastMessageDate: message.date,
            lastMessageSentDate: message.date,
          })
        }

        const savedMessage = await message.save();
        const savedThread = await thread.save();
        await savedThread.addMessage(savedMessage);

        return savedMessage;
      },
    },
    instanceMethods: {
      async setLabelsFromXGM(xGmLabels, {Label, preloadedLabels} = {}) {
        this.folderImapXGMLabels = JSON.stringify(xGmLabels);
        const labels = await Label.findXGMLabels(xGmLabels, {preloadedLabels})
        return this.setLabels(labels);
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

      // The uid in this header is simply the draft id and version concatenated.
      // Because this uid identifies the draft on the remote provider, we
      // regenerate it on each draft revision so that we can delete the old draft
      // and add the new one on the remote.
      regenerateHeaderMessageId() {
        this.headerMessageId = `<${this.id}-${this.version}@mailer.nylas.com>`
      },
      toJSON() {
        if (this.folder_id && !this.folder) {
          throw new Error("Message.toJSON called on a message where folder were not eagerly loaded.")
        }

        // When we request messages as a sub-object of a thread, we only
        // request the `id` field from the database. We still toJSON the
        // Message though and need to protect `this.date` from null
        // errors.
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
          date: this.date ? this.date.getTime() / 1000.0 : null,
          unread: this.unread,
          starred: this.starred,
          folder: this.folder,
          labels: this.labels,
          thread_id: this.threadId,
        };
      },
    },
    hooks: {
      beforeUpdate: (message) => {
        // Update the snippet if the body has changed
        if (!message.changed('body')) { return; }

        const plainText = striptags(message.body);
        // consolidate whitespace groups into single spaces and then truncate
        message.snippet = plainText.split(/\s+/).join(" ").substring(0, SNIPPET_LENGTH)
      },
    },
  });
};
