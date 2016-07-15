const PubsubConnector = require('./pubsub-connector')
const MessageTypes = require('./message-types')

module.exports = (db, sequelize) => {
  sequelize.addHook("afterCreate", ({dataValues, $modelOptions}) => {
    if ($modelOptions.name.singular === 'account') {
      PubsubConnector.notifyAccount(dataValues.id, {
        type: MessageTypes.ACCOUNT_CREATED,
      });
    }
  })
  sequelize.addHook("afterUpdate", ({dataValues, $modelOptions}) => {
    if ($modelOptions.name.singular === 'account') {
      PubsubConnector.notifyAccount(dataValues.id, {
        type: MessageTypes.ACCOUNT_UPDATED,
      });
    }
  })
  sequelize.addHook("afterDestroy", ({dataValues, $modelOptions}) => {
    if ($modelOptions.name.singular === 'account') {
      PubsubConnector.notifyAccount(dataValues.id, {
        type: MessageTypes.ACCOUNT_DELETED,
      });
    }
  })
}
