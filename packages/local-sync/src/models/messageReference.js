module.exports = (sequelize) => {
  return sequelize.define('messageReference', {
  }, {
    indexes: [
      // NOTE: When SQLite sets up this table, it creates an auto index in
      // the order ['messageId', 'referenceId']. This is the correct index we
      // need for queries requesting References for a certain Message.
      //
      // We need to create one more index to allow queries from the
      // reverse direction requesting Messages for a certain Reference.
      {fields: ['referenceId', 'messageId']},
    ],
  });
};
