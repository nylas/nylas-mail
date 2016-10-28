/* eslint no-cond-assign: 0 */
import { DOMUtils, ContenteditableExtension } from 'nylas-exports';

export default class BlockquoteManager extends ContenteditableExtension {
  static keyCommandHandlers() {
    return {
      "contenteditable:quote": this._onCreateBlockquote,
    };
  }

  static onKeyDown({editor, event}) {
    if (event.key === "Backspace") {
      if (this._isInBlockquote(editor) && this._isAtStartOfLine(editor)) {
        editor.outdent();
        event.preventDefault();
      }
    }
  }

  static _onCreateBlockquote({editor}) {
    editor.formatBlock("BLOCKQUOTE");
  }

  static _isInBlockquote(editor) {
    const sel = editor.currentSelection();
    if (!sel.isCollapsed) {
      return false;
    }
    return DOMUtils.closest(sel.anchorNode, "blockquote") != null;
  }

  static _isAtStartOfLine(editor) {
    const sel = editor.currentSelection();
    if (!sel.anchorNode) { return false; }
    if (!sel.isCollapsed) { return false; }
    if (sel.anchorOffset !== 0) { return false; }

    return this._ancestorRelativeLooksLikeBlock(sel.anchorNode);
  }

  static _ancestorRelativeLooksLikeBlock(node) {
    if (DOMUtils.looksLikeBlockElement(node)) {
      return true;
    }

    let sibling = node;
    while (sibling = sibling.previousSibling) {
      if (DOMUtils.looksLikeBlockElement(sibling)) {
        return true;
      }

      if (DOMUtils.looksLikeNonEmptyNode(sibling)) {
        return false;
      }
    }

    // never found block level element
    return this._ancestorRelativeLooksLikeBlock(node.parentNode);
  }
}
