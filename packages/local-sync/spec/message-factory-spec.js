const LocalDatabaseConnector = require('../src/shared/local-database-connector');
const {parseFromImap} = require('../src/shared/message-factory');
const {forEachJSONFixture, ACCOUNT_ID} = require('./helpers');

describe('MessageFactory', function MessageFactorySpecs() {
  beforeEach(() => {
    waitsForPromise(async () => {
      await LocalDatabaseConnector.ensureAccountDatabase(ACCOUNT_ID);
      const db = await LocalDatabaseConnector.forAccount(ACCOUNT_ID);
      const folder = await db.Folder.create({
        id: 'test-folder-id',
        accountId: ACCOUNT_ID,
        version: 1,
        name: 'Test Folder',
        role: null,
      });
      this.options = { accountId: ACCOUNT_ID, db, folder };
    })
  })

  afterEach(() => {
    LocalDatabaseConnector.destroyAccountDatabase(ACCOUNT_ID)
  })

  describe("parseFromImap", () => {
    forEachJSONFixture('MessageFactory/parseFromImap', (filename, json) => {
      it(`should correctly build message properties for ${filename}`, () => {
        const {imapMessage, desiredParts, result} = json;
        // requiring these to match makes it overly arduous to generate test
        // cases from real accounts
        const excludeKeys = new Set(['id', 'accountId', 'folderId', 'folder', 'labels']);

        waitsForPromise(async () => {
          const actual = await parseFromImap(imapMessage, desiredParts, this.options);
          for (const key of Object.keys(result)) {
            if (!excludeKeys.has(key)) {
              expect(actual[key]).toEqual(result[key]);
            }
          }
        });
      });
    })
  });
});
