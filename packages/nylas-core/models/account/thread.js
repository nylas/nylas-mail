const {JSONARRAYType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Thread = sequelize.define('thread', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    threadId: Sequelize.STRING,
    subject: Sequelize.STRING,
    snippet: Sequelize.STRING,
    unreadCount: Sequelize.INTEGER,
    starredCount: Sequelize.INTEGER,
    firstMessageDate: Sequelize.DATE,
    lastMessageDate: Sequelize.DATE,
    lastMessageReceivedDate: Sequelize.DATE,
    lastMessageSentDate: Sequelize.DATE,
    participants: JSONARRAYType('participants'),
  }, {
    classMethods: {
      associate: ({Category, Message, ThreadCategory}) => {
        Thread.belongsToMany(Category, {through: ThreadCategory})
        Thread.hasMany(Message, {as: 'messages'})
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        if (!(this.categories instanceof Array)) {
          throw new Error("Thread.toJSON called on a thread where categories were not eagerly loaded.")
        }
        if (!(this.messages instanceof Array)) {
          throw new Error("Thread.toJSON called on a thread where messages were not eagerly loaded. (Only need the IDs!)")
        }

        const response = {
          id: this.id,
          object: 'thread',
          folders: this.categories.filter(c => c.type === 'folder'),
          labels: this.categories.filter(c => c.type === 'label'),
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
