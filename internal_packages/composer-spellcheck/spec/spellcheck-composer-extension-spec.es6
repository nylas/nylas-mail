/* global waitsForPromise */

import fs from 'fs';
import path from 'path';

import SpellcheckComposerExtension from '../lib/spellcheck-composer-extension';
import {NylasSpellchecker, Message} from 'nylas-exports';

const initialPath = path.join(__dirname, 'fixtures', 'california-with-misspellings-before.html');
const initialHTML = fs.readFileSync(initialPath).toString();
const expectedPath = path.join(__dirname, 'fixtures', 'california-with-misspellings-after.html');
const expectedHTML = fs.readFileSync(expectedPath).toString();

describe("SpellcheckComposerExtension", () => {
  beforeEach(() => {
    // Avoid differences between node-spellcheck on different platforms
    const lookupPath = path.join(__dirname, 'fixtures', 'california-spelling-lookup.json');
    const spellings = JSON.parse(fs.readFileSync(lookupPath));
    spyOn(NylasSpellchecker, 'isMisspelled').andCallFake(word => spellings[word])
  });

  describe("update", () => {
    it("correctly walks a DOM tree and surrounds mispelled words", () => {
      const node = document.createElement('div');
      node.innerHTML = initialHTML;

      const editor = {
        rootNode: node,
        whilePreservingSelection: (cb) => cb(),
      };

      SpellcheckComposerExtension.update(editor);
      expect(node.innerHTML).toEqual(expectedHTML);
    });
  });

  describe("applyTransformsToDraft", () => {
    it("removes the spelling annotations it inserted", () => {
      const draft = new Message({ body: expectedHTML });
      const out = SpellcheckComposerExtension.applyTransformsToDraft({draft});
      expect(out.body).toEqual(initialHTML);
    });
  });

  describe("unapplyTransformsToDraft", () => {
    it("returns the magic no-op option", () => {
      const draft = new Message({ body: expectedHTML });
      const out = SpellcheckComposerExtension.unapplyTransformsToDraft({draft});
      expect(out).toEqual('unnecessary');
    });
  });
});
