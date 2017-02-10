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

function getMockServer() {
  return {
    routes: [],
    route: function route(r) {
      this.routes.push(r)
    },
  }
}

module.exports = {
  getTestDatabase,
  destroyTestDatabase,
  getMockServer,
}
