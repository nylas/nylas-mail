
const FetchFolderList = require('../../src/local-sync-worker/imap/fetch-folder-list');
const LocalDatabaseConnector = require('../../src/shared/local-database-connector');
const {forEachJSONFixture, ACCOUNT_ID, silentLogger} = require('../helpers');

xdescribe("FetchFolderList", function FetchFolderListSpecs() {
  beforeEach(async () => {
    await LocalDatabaseConnector.ensureAccountDatabase(ACCOUNT_ID);
    this.db = await LocalDatabaseConnector.forAccount(ACCOUNT_ID);

    this.stubImapBoxes = null;
    this.imap = {
      getBoxes: () => {
        return Promise.resolve(this.stubImapBoxes);
      },
    };
  });

  afterEach(() => {
    LocalDatabaseConnector.destroyAccountDatabase(ACCOUNT_ID)
  })

  describe("initial syncing", () => {
    forEachJSONFixture('FetchFolderList', (filename, json) => {
      it(`should create folders and labels correctly for boxes (${filename})`, async () => {
        const {boxes, expectedFolders, expectedLabels} = json;
        const provider = filename.split('-')[0];
        this.stubImapBoxes = boxes;

        const task = new FetchFolderList(provider, silentLogger);
        await task.run(this.db, this.imap);

        const folders = await this.db.Folder.findAll();
        expect(folders.map((f) => { return {name: f.name, role: f.role} })).toEqual(expectedFolders);

        const labels = await this.db.Label.findAll();
        expect(labels.map(f => { return {name: f.name, role: f.role} })).toEqual(expectedLabels);
      });
    });
  });
});
