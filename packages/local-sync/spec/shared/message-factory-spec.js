const {parseFromImap, parseSnippet, parseContacts} = require('../../src/shared/message-factory');
const {forEachJSONFixture, forEachHTMLAndTXTFixture, ACCOUNT_ID, getTestDatabase} = require('./helpers');

xdescribe('MessageFactory', function MessageFactorySpecs() {
  beforeEach(() => {
    waitsForPromise(async () => {
      const db = await getTestDatabase()
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
  body: '<pre>The quick brown fox\n\n\tjumps over the lazy</pre>',
  snippet: 'The quick brown fox jumps over the lazy',
}, {
  purpose: 'truncate long plaintext without breaking words',
  body: '<pre>The quick brown fox jumps over the lazy dog and then the lazy dog rolls over and sighs. The fox turns around in a circle and then jumps onto a bush! It grins wickedly and wags its fat tail. As the lazy dog puts its head on its paws and cracks a sleepy eye open, a slow grin forms on its face. The fox has fallen into the bush and is yelping and squeaking.</pre>',
  snippet: 'The quick brown fox jumps over the lazy dog and then the lazy dog rolls over and sighs. The fox turns',
}, {
  purpose: 'process basic HTML correctly',
  body: '<html><title>All About Ponies</title><h1>PONIES AND RAINBOWS AND UNICORNS</h1><p>Unicorns are native to the hillsides of Flatagonia.</p></html>',
  snippet: 'PONIES AND RAINBOWS AND UNICORNS Unicorns are native to the hillsides of Flatagonia.',
}, {
  purpose: 'properly strip rogue styling inside of <body> and trim whitespace in HTML',
  body: '<html>\n  <head></head>\n  <body>\n    <style>\n    body { width: 100% !important; min-width: 100%; -webkit-font-smoothing: antialiased; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; margin: 0; padding: 0; background: #fafafa;\n    </style>\n  <p>Look ma, no            CSS!</p></body></html>',
  snippet: 'Look ma, no CSS!',
}, {
  purpose: 'properly process <br/> and <div/>',
  body: '<p>Unicorns are <div>native</div>to the<br/>hillsides of<br/>Flatagonia.</p>',
  snippet: 'Unicorns are native to the hillsides of Flatagonia.',
}, {
  purpose: 'properly strip out HTML comments',
  body: '<p>Unicorns are<!-- an HTML comment! -->native to the</p>',
  snippet: 'Unicorns are native to the',
}, {
  purpose: "don't add extraneous spaces after text format markup",
  body: `
  <td style="padding: 0px 10px">
            Hey there, <b>Nylas</b>!<br>
            You have a new follower on Product Hunt.
          </td>`,
  snippet: 'Hey there, Nylas! You have a new follower on Product Hunt.',
},
]

const contactsTestCases = [{
  purpose: "not erroneously split contact names on commas",
  // NOTE: inputs must be in same format as output by mimelib.parseHeader
  input: ['"Little Bo Peep, The Hill" <bopeep@example.com>'],
  output: [{name: "Little Bo Peep, The Hill", email: "bopeep@example.com"}],
}, {
  purpose: "extract two separate contacts, removing quotes properly & respecing unicode",
  input: ['AppleBees Zé <a@example.com>, "Tiger Zen" b@example.com'],
  output: [
    {name: 'AppleBees Zé', email: 'a@example.com'},
    {name: 'Tiger Zen', email: 'b@example.com'},
  ],
}, {
  purpose: "correctly concatenate multiple array elements (from multiple header lines)",
  input: ['Yubi Key <yubi@example.com>', 'Smokey the Bear <smokey@example.com>'],
  output: [
    {name: 'Yubi Key', email: 'yubi@example.com'},
    {name: 'Smokey the Bear', email: 'smokey@example.com'},
  ],
},
]

describe('MessageFactoryHelpers', function MessageFactoryHelperSpecs() {
  describe('parseSnippet (basic)', () => {
    snippetTestCases.forEach(({purpose, body, snippet}) => {
      it(`should ${purpose}`, () => {
        const parsedSnippet = parseSnippet(body);
        expect(parsedSnippet).toEqual(snippet);
      });
    });
  });
  describe('parseSnippet (real world)', () => {
    forEachHTMLAndTXTFixture('MessageFactory/parseSnippet', (filename, html, txt) => {
      it(`should correctly extract the snippet from the html`, () => {
        const parsedSnippet = parseSnippet(html);
        expect(parsedSnippet).toEqual(txt);
      });
    });
  });
  describe('parseContacts (basic)', () => {
    contactsTestCases.forEach(({purpose, input, output}) => {
      it(`should ${purpose}`, () => {
        const parsedContacts = parseContacts(input);
        expect(parsedContacts).toEqual(output);
      });
    });
  });
});
