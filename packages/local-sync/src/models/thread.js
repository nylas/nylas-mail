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
  }, {
    indexes: [
      { fields: ['id'], unique: true },
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
      associate: ({Thread, Folder, ThreadFolder, Label, ThreadLabel, Message}) => {
        Thread.belongsToMany(Folder, {through: ThreadFolder})
        Thread.belongsToMany(Label, {through: ThreadLabel})
        Thread.hasMany(Message)
      },
    },
    instanceMethods: {
      async updateLabelsAndFolders() {
        const messages = await this.getMessages();
        const labelIds = new Set()
        const folderIds = new Set()

        await Promise.all(messages.map(async (msg) => {
          const labels = await msg.getLabels({attributes: ['id']})
          labels.forEach(({id}) => labelIds.add(id));
          folderIds.add(msg.folderId)
        }));

        await Promise.all([
          this.setLabels(Array.from(labelIds)),
          this.setFolders(Array.from(folderIds)),
        ]);

        return this.save();
      },
      async updateFromMessage(message) {
        if (message.isDraft) {
          return this;
        }

        if (!(message.labels instanceof Array)) {
          throw new Error("Expected message.labels to be an inflated array.");
        }
        if (!message.folder) {
          throw new Error("Expected message.folder value to be present.");
        }

        // Update thread participants
        const {to, cc, bcc, from} = message;
        const participantEmails = this.participants.map(contact => contact.email);
        const newParticipants = to.concat(cc, bcc, from).filter(contact => {
          if (participantEmails.includes(contact.email)) {
            return false;
          }
          participantEmails.push(contact.email);
          return true;
        })
        this.participants = this.participants.concat(newParticipants);

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

        // Figure out if the message is sent or received and update more dates
        const isSent = (
          message.folder.role === 'sent' ||
          !!message.labels.find(l => l.role === 'sent')
        );

        if (isSent && ((message.date > this.lastMessageSentDate) || !this.lastMessageSentDate)) {
          this.lastMessageSentDate = message.date;
        }
        if (((message.date > this.lastMessageReceivedDate) || !this.lastMessageReceivedDate)) {
          this.lastMessageReceivedDate = message.date;
        }

        const savedThread = await this.save();

        // Update folders/labels
        // This has to be done after the thread has been saved, because the
        // thread may not have had an id assigned yet. addFolder()/addLabel()
        // need an existing thread id to work properly.
        if (!savedThread.folders.find(f => f.id === message.folderId)) {
          // Since multiple messages from the same thread may be being
          // processed at the same time, it's possible the association has
          // already been added. Carry on without error in that case.
          try {
            await savedThread.addFolder(message.folder)
          } catch (err) {
            if (err.name !== "SequelizeUniqueConstraintError") {
              throw err;
            }
          }
        }
        for (const label of message.labels) {
          if (!savedThread.labels.find(l => l.id === label)) {
            // Since multiple messages from the same thread may be being
            // processed at the same time, it's possible the association has
            // already been added. Carry on without error in that case.
            try {
              await savedThread.addLabel(label)
            } catch (err) {
              if (err.name !== "SequelizeUniqueConstraintError") {
                throw err;
              }
            }
          }
        }

        return savedThread.save();
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
          folders: this.folders.map(f => f.toJSON()),
          labels: this.labels.map(l => l.toJSON()),
          account_id: this.accountId,
          participants: this.participants,
          subject: this.subject,
          snippet: this.snippet,
          unread: this.unreadCount > 0,
          starred: this.starredCount > 0,
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
