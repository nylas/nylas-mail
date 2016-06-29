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
        if (!this.categories) {
          throw new Error("Thread.toJSON called on a thread where categories were not eagerly loaded.")
        }
        const folders = this.categories.filter(c => c.type === 'folder');
        const labels = this.categories.filter(c => c.type === 'label');
        return {
          id: this.id,
          object: 'thread',
          folders: folders,
          labels: labels,
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
      },
    },
  });

  return Thread;
};
