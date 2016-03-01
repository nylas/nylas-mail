/* global waitsForPromise */

import fs from 'fs';
import path from 'path';

import SpellcheckComposerExtension from '../lib/spellcheck-composer-extension';

const initialHTML = fs.readFileSync(path.join(__dirname, 'fixtures', 'california-with-misspellings-before.html')).toString();
const expectedHTML = fs.readFileSync(path.join(__dirname, 'fixtures', 'california-with-misspellings-after.html')).toString();

describe("SpellcheckComposerExtension", ()=> {
  beforeEach(()=> {
    // Avoid differences between node-spellcheck on different platforms
    const spellings = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', 'california-spelling-lookup.json')));
    spyOn(SpellcheckComposerExtension, 'isMisspelled').andCallFake(word=> spellings[word])
  });

  describe("update", ()=> {
    it("correctly walks a DOM tree and surrounds mispelled words", ()=> {
      const node = document.createElement('div');
      node.innerHTML = initialHTML;

      const editor = {
        rootNode: node,
        whilePreservingSelection: (cb)=> {
          return cb();
        },
      };

      SpellcheckComposerExtension.update(editor);
      expect(node.innerHTML).toEqual(expectedHTML);
    });
  });

  describe("finalizeSessionBeforeSending", ()=> {
    it("removes the annotations it inserted", ()=> {
      const session = {
        draft: ()=> {
          return {
            body: expectedHTML,
          };
        },
        changes: {
          add: jasmine.createSpy('add').andReturn(Promise.resolve()),
        },
      };

      waitsForPromise(()=> {
        return SpellcheckComposerExtension.finalizeSessionBeforeSending({session}).then(()=> {
          expect(session.changes.add).toHaveBeenCalledWith({body: initialHTML});
        });
      });
    });
  });
});
