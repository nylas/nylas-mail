const PubsubConnector = require('./pubsub-connector')
const MessageTypes = require('./message-types')

module.exports = (db, sequelize) => {
  sequelize.addHook("afterCreate", ({dataValues, $modelOptions}) => {
    if ($modelOptions.name.singular === 'account') {
      PubsubConnector.broadcastClient().lpushAsync('accounts:unclaimed', dataValues.id);
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
  // TODO delete account from redis
  // sequelize.addHook("afterDelete", ({dataValues, $modelOptions}) => {
  // })
}
