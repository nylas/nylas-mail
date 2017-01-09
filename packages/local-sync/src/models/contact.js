const crypto = require('crypto')

/**
 * NOTE: SQLITE creates an index on the `primaryKey` (the ID) for you.
 * This "Auto Index" is called `sqlite_autoindex_contacts_1`.
 *
 * If you run `EXPLAIN QUERY PLAN SELECT * FROM contacts WHERE id=1` you
 * get:
 *   SEARCH TABLE contacts USING INDEX sqlite_autoindex_contacts_1
 * (id=?)
 */
module.exports = (sequelize, Sequelize) => {
  return sequelize.define('contact', {
    id: {type: Sequelize.STRING(65), primaryKey: true},
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    email: Sequelize.STRING,
  }, {
    classMethods: {
      hash({email}) {
        return crypto.createHash('sha256').update(email, 'utf8').digest('hex');
      },
    },
    instanceMethods: {
      toJSON() {
        return {
          id: `${this.id}`,
          account_id: this.accountId,
          object: 'contact',
          email: this.email,
          name: this.name,
        }
      },
    },
  })
}
