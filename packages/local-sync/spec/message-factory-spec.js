const LocalDatabaseConnector = require('../src/shared/local-database-connector');
const {parseFromImap, extractSnippet} = require('../src/shared/message-factory');
const {forEachJSONFixture, forEachHTMLAndTXTFixture, ACCOUNT_ID} = require('./helpers');

fdescribe('MessageFactory', function MessageFactorySpecs() {
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

const snippetTestCases = [{
  purpose: 'trim whitespace in basic plaintext',
  plainBody: 'The quick brown fox\n\n\tjumps over the lazy',
  htmlBody: null,
  snippet: 'The quick brown fox jumps over the lazy',
}, {
  purpose: 'truncate long plaintext without breaking words',
  plainBody: 'The quick brown fox jumps over the lazy dog and then the lazy dog rolls over and sighs. The fox turns around in a circle and then jumps onto a bush! It grins wickedly and wags its fat tail. As the lazy dog puts its head on its paws and cracks a sleepy eye open, a slow grin forms on its face. The fox has fallen into the bush and is yelping and squeaking.',
  htmlBody: null,
  snippet: 'The quick brown fox jumps over the lazy dog and then the lazy dog rolls over and sighs. The fox turns',
}, {
  purpose: 'prefer HTML to plaintext, and process basic HTML correctly',
  plainBody: 'This email would look TOTES AMAZING if your silly mail client supported HTML.',
  htmlBody: '<html><title>All About Ponies</title><h1>PONIES AND RAINBOWS AND UNICORNS</h1><p>Unicorns are native to the hillsides of Flatagonia.</p></html>',
  snippet: 'PONIES AND RAINBOWS AND UNICORNS Unicorns are native to the hillsides of Flatagonia.',
}, {
  purpose: 'properly strip rogue styling inside of <body> and trim whitespace in HTML',
  plainBody: null,
  htmlBody: '<html>\n  <head></head>\n  <body>\n    <style>\n    body { width: 100% !important; min-width: 100%; -webkit-font-smoothing: antialiased; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; margin: 0; padding: 0; background: #fafafa;\n    </style>\n  <p>Look ma, no            CSS!</p></body></html>',
  snippet: 'Look ma, no CSS!',
}, {
  purpose: 'properly process <br/> and <div/>',
  plainBody: null,
  htmlBody: '<p>Unicorns are <div>native</div>to the<br/>hillsides of<br/>Flatagonia.</p>',
  snippet: 'Unicorns are native to the hillsides of Flatagonia.',
}, {
  purpose: 'properly strip out HTML comments',
  plainBody: null,
  htmlBody: '<p>Unicorns are<!-- an HTML comment! -->native to the</p>',
  snippet: 'Unicorns are native to the',
},
]

describe('MessageFactoryHelpers', function MessageFactoryHelperSpecs() {
  describe('extractSnippet (basic)', () => {
    snippetTestCases.forEach(({purpose, plainBody, htmlBody, snippet}) => {
      it(`should ${purpose}`, () => {
        const parsedSnippet = extractSnippet(plainBody, htmlBody);
        expect(parsedSnippet).toEqual(snippet);
      });
    });
  });
  describe('extractSnippet (real world)', () => {
    forEachHTMLAndTXTFixture('MessageFactory/extractSnippet', (filename, html, txt) => {
      it(`should correctly extract the snippet from the html`, () => {
        const parsedSnippet = extractSnippet(null, html);
        expect(parsedSnippet).toEqual(txt);
      });
    });
  });
});
