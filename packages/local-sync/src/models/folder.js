const crypto = require('crypto')
const {DatabaseTypes: {buildJSONColumnOptions}} = require('isomorphic-core');
const {formatImapPath} = require('../shared/imap-paths-utils');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('folder', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    role: Sequelize.STRING,
    syncState: buildJSONColumnOptions('syncState'),
  }, {
    indexes: [
      {
        unique: true,
        fields: ['role'],
      },
      {
        unique: true,
        fields: ['id'],
      },
    ],
    classMethods: {
      associate({Folder, Message, Thread}) {
        Folder.hasMany(Message)
        Folder.belongsToMany(Thread, {through: 'thread_folders'})
      },

      hash({boxName, accountId}) {
        return crypto.createHash('sha256').update(`${accountId}${boxName}`, 'utf8').digest('hex')
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: `${this.id}`,
          account_id: this.accountId,
          object: 'folder',
          name: this.role,
          display_name: formatImapPath(this.name),
        };
      },
    },
  });
};
