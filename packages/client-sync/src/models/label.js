const crypto = require('crypto')
const {formatImapPath} = require('../shared/imap-paths-utils');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('label', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    role: Sequelize.STRING,
  }, {
    classMethods: {
      associate({Label, Message, MessageLabel, Thread, ThreadLabel}) {
        Label.belongsToMany(Message, {through: MessageLabel})
        Label.belongsToMany(Thread, {through: ThreadLabel})
      },

      findXGMLabels(xGmLabels, {preloadedLabels} = {}) {
        if (!xGmLabels) {
          return Promise.resolve();
        }
        const labelNames = xGmLabels.filter(l => l[0] !== '\\')
        const labelRoles = xGmLabels.filter(l => l[0] === '\\').map(l => l.substr(1).toLowerCase())

        if (preloadedLabels) {
          return Promise.resolve(
            preloadedLabels.filter(l => labelNames.includes(l.name) || labelRoles.includes(l.role))
          );
        }
        return this.findAll({
          where: sequelize.or({name: labelNames}, {role: labelRoles}),
        })
      },

      hash({boxName, accountId}) {
        return crypto.createHash('sha256').update(`${accountId}${boxName}`, 'utf8').digest('hex')
      },
    },
    instanceMethods: {
      imapLabelIdentifier() {
        if (this.role) {
          return `\\${this.role[0].toUpperCase()}${this.role.slice(1)}`
        }
        return this.name;
      },

      toJSON() {
        return {
          id: `${this.id}`,
          account_id: this.accountId,
          object: 'label',
          name: this.role,
          display_name: formatImapPath(this.name),
          imap_name: this.name,
        };
      },
    },
  });
};
