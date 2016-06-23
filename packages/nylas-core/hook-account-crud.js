const PubsubConnector = require('./pubsub-connector')

module.exports = (db, sequelize) => {
  sequelize.addHook("afterCreate", ({dataValues, $modelOptions}) => {
    if ($modelOptions.name.singular === 'Account') {
      PubsubConnector.broadcastClient().lpushAsync('accounts:unclaimed', dataValues.id);
    }
  })
  sequelize.addHook("afterUpdate", ({dataValues, $modelOptions}) => {
    if ($modelOptions.name.singular === 'Account') {
      PubsubConnector.notifyAccountChange(dataValues.id);
    }
  })
  // TODO delete account from redis
  // sequelize.addHook("afterDelete", ({dataValues, $modelOptions}) => {
  // })
}
