const path = require('path');
const fs = require('fs');
const LocalDatabaseConnector = require('../src/shared/local-database-connector');
const {parseFromImap} = require('../src/shared/message-factory');

const FIXTURES_PATH = path.join(__dirname, 'fixtures')

describe('MessageFactory', function MessageFactorySpecs() {
  beforeEach(() => {
    waitsForPromise(async () => {
      const accountId = 'test-account-id';
      await LocalDatabaseConnector.ensureAccountDatabase(accountId);
      const db = await LocalDatabaseConnector.forAccount(accountId);
      const folder = await db.Folder.create({
        id: 'test-folder-id',
        accountId: accountId,
        version: 1,
        name: 'Test Folder',
        role: null,
      });
      this.options = { accountId, db, folder };
    })
  })

  describe("parseFromImap", () => {
    const fixturesDir = path.join(FIXTURES_PATH, 'MessageFactory', 'parseFromImap');
    const filenames = fs.readdirSync(fixturesDir).filter(f => f.endsWith('.json'));

    filenames.forEach((filename) => {
      it(`should correctly build message properties for ${filename}`, () => {
        const inJSON = JSON.parse(fs.readFileSync(path.join(fixturesDir, filename)));
        const {imapMessage, desiredParts, result} = inJSON;

        waitsForPromise(async () => {
          const actual = await parseFromImap(imapMessage, desiredParts, this.options);
          expect(actual).toEqual(result)
        });
      });
    })
  });
});
