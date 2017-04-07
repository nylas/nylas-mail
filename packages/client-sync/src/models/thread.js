const {DatabaseTypes: {JSONArrayColumn}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('thread', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    remoteThreadId: Sequelize.STRING,
    subject: Sequelize.STRING(500),
    snippet: Sequelize.STRING(255),
    unreadCount: {
      type: Sequelize.INTEGER,
      get: function get() { return this.getDataValue('unreadCount') || 0 },
    },
    starredCount: {
      type: Sequelize.INTEGER,
      get: function get() { return this.getDataValue('starredCount') || 0 },
    },
    firstMessageDate: Sequelize.DATE,
    lastMessageDate: Sequelize.DATE,
    lastMessageReceivedDate: Sequelize.DATE,
    lastMessageSentDate: Sequelize.DATE,
    participants: JSONArrayColumn('participants'),
    hasAttachments: {type: Sequelize.BOOLEAN, defaultValue: false},
  }, {
    indexes: [
      { fields: ['subject'] },
      { fields: ['remoteThreadId'] },
    ],
    classMethods: {
      MAX_THREAD_LENGTH: 500,
      requiredAssociationsForJSON: ({Folder, Label, Message}) => {
        return [
          {model: Folder},
          {model: Label},
          {
            model: Message,
            attributes: ['id'],
          },
        ]
      },
      associate: ({Thread, Folder, ThreadFolder, Label, ThreadLabel, Message, Reference}) => {
        Thread.belongsToMany(Folder, {through: ThreadFolder})
        Thread.belongsToMany(Label, {through: ThreadLabel})
        Thread.hasMany(Message, {onDelete: 'cascade', hooks: true})
        // TODO: what is the desired cascade behaviour for references?
        Thread.hasMany(Reference)
      },
    },
    instanceMethods: {
      async updateLabelsAndFolders({transaction} = {}) {
        const messages = await this.getMessages({attributes: ['id', 'folderId'], transaction});
        const labelIds = new Set()
        const folderIds = new Set()

        await Promise.all(messages.map(async (msg) => {
          const labels = await msg.getLabels({attributes: ['id'], transaction})
          labels.forEach(({id}) => {
            if (!id) return;
            labelIds.add(id);
          })
          if (!msg.folderId) return;
          folderIds.add(msg.folderId)
        }));

        await Promise.all([
          this.setLabels(Array.from(labelIds), {transaction}),
          this.setFolders(Array.from(folderIds), {transaction}),
        ]);

        return this.save({transaction});
      },

      // Updates the attributes that don't require an external set to prevent
      // duplicates. Currently includes starred/unread counts, various date
      // values, and snippet. Does not save the thread.
      _updateSimpleMessageAttributes(message) {
        // Update starred/unread counts
        this.starredCount += message.starred ? 1 : 0;
        this.unreadCount += message.unread ? 1 : 0;

        // Update dates/snippet
        if (!this.lastMessageDate || (message.date > this.lastMessageDate)) {
          this.lastMessageDate = message.date;
          this.snippet = message.snippet;
        }
        if (!this.firstMessageDate || (message.date < this.firstMessageDate)) {
          this.firstMessageDate = message.date;
        }

        // Figure out if the message is sent and/or received and update more dates
        // Note that `isReceived` is not mutually exclusive of `isSent` when
        // labels are involved, because users can send emails to themselves.
        const isSent = (
          message.folder.role === 'sent' ||
          !!message.labels.find(l => l.role === 'sent')
        );
        const isReceived = (
          message.folder.role !== 'sent' ||
          !!message.labels.find(l => l.role !== 'sent')
        )

        if (isSent && (!this.lastMessageSentDate || (message.date > this.lastMessageSentDate))) {
          this.lastMessageSentDate = message.date;
        }
        if (isReceived && (!this.lastMessageReceivedDate || (message.date > this.lastMessageReceivedDate))) {
          this.lastMessageReceivedDate = message.date;
        }
      },

      async updateFromMessages({db, messages, recompute, transaction} = {}) {
        if (!(this.folders instanceof Array) || !(this.labels instanceof Array)) {
          throw new Error('Thread.updateFromMessages() expected .folders and .labels to be inflated arrays')
        }

        let _messages = messages;
        if (recompute) {
          if (!db) {
            throw new Error('Cannot recompute thread attributes without a database reference.')
          }
          const {Label, Folder, File} = db;
          _messages = await this.getMessages({
            include: [{model: Label}, {model: Folder}, {model: File}],
            attributes: {exclude: ['body']},
          });
          if (_messages.length === 0) {
            return this.destroy();
          }

          this.folders = [];
          this.labels = [];
          this.participants = [];
          this.unreadCount = 0;
          this.starredCount = 0;
          this.hasAttachments = false;
          this.snippet = null;
          this.lastMessageDate = null;
          this.firstMessageDate = null;
          this.lastMessageSentDate = null;
          this.lastMessageReceivedDate = null;
        } else {
          // If we're not recomputing from all of the thread's messages, we need
          // to know which messages to update from
          if (!(_messages instanceof Array)) {
            throw new Error('Thread.updateFromMessages() expected an array of messages')
          }
        }

        const folderIds = new Set(this.folders.map(f => f.id));
        const labelIds = new Set(this.labels.map(l => l.id));
        const participantEmails = new Set(this.participants.map(p => p.email));

        for (const message of _messages) {
          if (!(message.labels instanceof Array)) {
            throw new Error("Expected message.labels to be an inflated array.");
          }
          if (!message.folder) {
            throw new Error("Expected message.folder value to be present.");
          }

          folderIds.add(message.folder.id)
          message.labels.forEach(label => labelIds.add(label.id))

          this._updateSimpleMessageAttributes(message);

          const {to, cc, bcc, from} = message;
          to.concat(cc, bcc, from).forEach(participant => {
            if (participantEmails.has(participant.email)) {
              return;
            }
            participantEmails.add(participant.email)
            this.participants = [...this.participants, participant]
          })

          // message.files only needs to be inflated if we're recomputing
          // the thread. Otherwise, .hasAttachments is set after we run
          // extractFiles on each message.
          if (!this.hasAttachments && message.files instanceof Array) {
            this.hasAttachments = message.files.some(f => !f.contentId);
          }
        }

        // Setting folders and labels cannot be done on a thread without an id
        const savedThread = await this.save({transaction});

        await Promise.all([
          savedThread.setFolders(Array.from(folderIds), {transaction}),
          savedThread.setLabels(Array.from(labelIds), {transaction}),
        ])
        return savedThread.save({transaction});
      },

      toJSON() {
        if (!(this.labels instanceof Array)) {
          throw new Error("Thread.toJSON called on a thread where labels were not eagerly loaded.")
        }
        if (!(this.folders instanceof Array)) {
          throw new Error("Thread.toJSON called on a thread where folders were not eagerly loaded.")
        }
        if (!(this.messages instanceof Array)) {
          throw new Error("Thread.toJSON called on a thread where messages were not eagerly loaded. (Only need the IDs!)")
        }

        const response = {
          id: `${this.id}`,
          object: 'thread',
          message_ids: this.messages.map(m => m.id),
          folders: this.folders.map(f => f.toJSON()),
          labels: this.labels.map(l => l.toJSON()),
          account_id: this.accountId,
          participants: this.participants,
          subject: this.subject,
          snippet: this.snippet,
          unread: this.unreadCount > 0,
          starred: this.starredCount > 0,
          has_attachments: this.hasAttachments,
          last_message_timestamp: this.lastMessageDate ? this.lastMessageDate.getTime() / 1000.0 : null,
          last_message_sent_timestamp: this.lastMessageSentDate ? this.lastMessageSentDate.getTime() / 1000.0 : null,
          last_message_received_timestamp: this.lastMessageReceivedDate ? this.lastMessageReceivedDate.getTime() / 1000.0 : null,
        };

        const expanded = this.messages[0] ? !!this.messages[0].accountId : false;
        if (expanded) {
          response.messages = this.messages;
        } else {
          response.message_ids = this.messages.map(m => m.id);
        }

        return response;
      },
    },
  });
};
