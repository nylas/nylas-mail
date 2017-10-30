import fs from 'fs';
import path from 'path';
import { Spellchecker, Message } from 'mailspring-exports';

import SpellcheckComposerExtension from '../lib/spellcheck-composer-extension';

const initialPath = path.join(__dirname, 'fixtures', 'california-with-misspellings-before.html');
const initialHTML = fs.readFileSync(initialPath).toString();
const afterPath = path.join(__dirname, 'fixtures', 'california-with-misspellings-after.html');
const afterHTML = fs.readFileSync(afterPath).toString();

describe('SpellcheckComposerExtension', function spellcheckComposerExtension() {
  beforeEach(() => {
    // Avoid differences between node-spellcheck on different platforms
    const lookupPath = path.join(__dirname, 'fixtures', 'california-spelling-lookup.json');
    const spellings = JSON.parse(fs.readFileSync(lookupPath));
    spyOn(Spellchecker, 'isMisspelled').andCallFake(word => spellings[word]);
    spyOn(Spellchecker.handler, 'provideHintText').andReturn({
      then(cb) {
        cb();
      },
    });
  });

  describe('onContentChanged', () => {
    it('correctly walks a DOM tree and surrounds mispelled words', () => {
      const node = document.createElement('div');
      node.innerHTML = initialHTML;

      const editor = {
        rootNode: node,
        whilePreservingSelection: cb => cb(),
      };

      SpellcheckComposerExtension.onContentChanged({ editor });
      advanceClock(1000); // Wait for debounce
      advanceClock(1); // Wait for defer
      expect(node.innerHTML).toEqual(afterHTML);
    });

    it('does not mark misspelled words inside A, CODE and PRE tags', () => {
      const node = document.createElement('div');
      node.innerHTML = `
      <br>
      This is a testst! I have a few misspellled words.
      <code>myvariable</code>
      <pre>
         fragmen = document.applieed();
      </pre>
      <a href="apple.com">I like appples!</a>
      <br>
      This is back to normall.
      `;

      const editor = {
        rootNode: node,
        whilePreservingSelection: cb => cb(),
      };

      SpellcheckComposerExtension.onContentChanged({ editor });
      advanceClock(1000); // Wait for debounce
      advanceClock(1); // Wait for defer
      expect(node.innerHTML).toEqual(`
      <br>
      This is a <spelling class="misspelled">testst</spelling>! I have a few <spelling class="misspelled">misspellled</spelling> words.
      <code>myvariable</code>
      <pre>         fragmen = document.applieed();
      </pre>
      <a href="apple.com">I like appples!</a>
      <br>
      This is back to <spelling class="misspelled">normall</spelling>.
      `);
    });

    it('handles unicode letters in words correctly', () => {
      //spyOn(Spellchecker, 'isMisspelled').andCallFake(word => true);
      const node = document.createElement('div');
      node.innerHTML = `
        <br>
        Schöße, égalité “пустынных”, ಸತ್ಯಾವತಾರ. misspellled.
        `;

      const editor = {
        rootNode: node,
        whilePreservingSelection: cb => cb(),
      };

      SpellcheckComposerExtension.onContentChanged({ editor });
      advanceClock(1000); // Wait for debounce
      advanceClock(1); // Wait for defer
      expect(node.innerHTML).toEqual(`
        <br>
        <spelling class="misspelled">Schöße</spelling>, <spelling class="misspelled">égalité</spelling> “<spelling class="misspelled">пустынных</spelling>”, <spelling class="misspelled">ಸತ್ಯಾವತಾರ</spelling>. <spelling class="misspelled">misspellled</spelling>.
        `);
    });
  });

  describe('applyTransformsForSending', () => {
    it('removes the spelling annotations it inserted', () => {
      const draft = new Message({ body: afterHTML });
      const fragment = document.createDocumentFragment();
      const draftBodyRootNode = document.createElement('root');
      fragment.appendChild(draftBodyRootNode);
      draftBodyRootNode.innerHTML = afterHTML;
      SpellcheckComposerExtension.applyTransformsForSending({ draftBodyRootNode, draft });
      expect(draftBodyRootNode.innerHTML).toEqual(initialHTML);
    });
  });
});
