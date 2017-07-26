import {DatabaseConnector} from 'cloud-core'
import {executeJasmine} from 'isomorphic-core'
import {getTestDatabase, destroyTestDatabase} from './helpers'

executeJasmine({
  beforeEach: () => {
    global.Logger = console;
    spyOn(DatabaseConnector, 'forShared').and.callFake(getTestDatabase)
  },
  afterEach: async () => {
    await destroyTestDatabase();
  },
})
