import {DatabaseConnector} from 'cloud-core'

let testDB = null

async function getTestDatabase() {
  testDB = testDB || await DatabaseConnector._sequelizeForShared({test: true})
  return testDB
}

async function destroyTestDatabase() {
  if (testDB) {
    await testDB.sequelize.drop()
    testDB = null
  }
}

module.exports = {
  getTestDatabase,
  destroyTestDatabase,
}
