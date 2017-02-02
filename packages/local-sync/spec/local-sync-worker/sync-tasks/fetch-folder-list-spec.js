
const FetchFolderList = require('../../../src/local-sync-worker/sync-tasks/fetch-folder-list.imap.es6');
const {forEachJSONFixture, silentLogger, getTestDatabase} = require('../helpers');

xdescribe("FetchFolderList", function FetchFolderListSpecs() {
  beforeEach(async () => {
    this.db = await getTestDatabase()

    this.stubImapBoxes = null;
    this.imap = {
      getBoxes: () => {
        return Promise.resolve(this.stubImapBoxes);
      },
    };
  });

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
