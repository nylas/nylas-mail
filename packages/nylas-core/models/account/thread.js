const {JSONARRAYType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Thread = sequelize.define('thread', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    threadId: Sequelize.STRING,
    subject: Sequelize.STRING(500),
    snippet: Sequelize.STRING(255),
    unreadCount: Sequelize.INTEGER,
    starredCount: Sequelize.INTEGER,
    firstMessageDate: Sequelize.DATE,
    lastMessageDate: Sequelize.DATE,
    lastMessageReceivedDate: Sequelize.DATE,
    lastMessageSentDate: Sequelize.DATE,
    participants: JSONARRAYType('participants'),
  }, {
    charset: 'utf8',
    indexes: [
      { fields: ['subject'] },
      { fields: ['threadId'] },
    ],
    classMethods: {
      requiredAssociationsForJSON: () => {
        return [
          {model: sequelize.models.folder},
          {model: sequelize.models.label},
          {
            model: sequelize.models.message,
            attributes: ['id'],
          },
        ]
      },
      associate: ({Folder, Label, Message}) => {
        Thread.belongsToMany(Folder, {through: 'thread_folders'})
        Thread.belongsToMany(Label, {through: 'thread_labels'})
        Thread.hasMany(Message)
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
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
          id: this.id,
          object: 'thread',
          folders: this.folders,
          labels: this.labels,
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

  return Thread;
};
