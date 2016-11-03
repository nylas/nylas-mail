import { DOMUtils, ContenteditableExtension } from 'nylas-exports';

export default class TabManager extends ContenteditableExtension {
  static onKeyDown({editor, event}) {
    // This is a special case where we don't want to bubble up the event to
    // the keymap manager if the extension prevented the default behavior
    if (event.defaultPrevented) {
      event.stopPropagation();
      return;
    }

    if (event.key === "Tab") {
      this._onTabDownDefaultBehavior(editor, event);
      return;
    }
  }

  static _onTabDownDefaultBehavior(editor, event) {
    const selection = editor.currentSelection();

    if (selection && selection.isCollapsed) {
      if (event.shiftKey) {
        if (DOMUtils.isAtTabChar(selection)) {
          this._removeLastCharacter(editor);
        } else {
          return; // Don't stop propagation
        }
      } else {
        editor.insertText("\t");
      }
    } else {
      if (event.shiftKey) {
        editor.insertText("");
      } else {
        editor.insertText("\t");
      }
    }
    event.preventDefault();
    event.stopPropagation();
  }

  static _removeLastCharacter(editor) {
    if (DOMUtils.isSelectionInTextNode(editor.currentSelection())) {
      const node = editor.currentSelection().anchorNode;
      const offset = editor.currentSelection().anchorOffset;
      editor.currentSelection().setBaseAndExtent(node, offset - 1, node, offset);
      editor.delete();
    }
  }
}
