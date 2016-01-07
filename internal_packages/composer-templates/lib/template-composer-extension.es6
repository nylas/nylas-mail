import {DOMUtils, ComposerExtension} from 'nylas-exports';

class TemplatesComposerExtension extends ComposerExtension {

  static warningsForSending({draft}) {
    const warnings = [];
    if (draft.body.search(/<code[^>]*empty[^>]*>/i) > 0) {
      warnings.push('with an empty template area');
    }
    return warnings;
  }

  static finalizeSessionBeforeSending({session}) {
    const body = session.draft().body;
    const clean = body.replace(/<\/?code[^>]*>/g, '');
    if (body !== clean) {
      return session.changes.add({body: clean});
    }
  }

  static onClick({editor, event}) {
    const node = event.target;
    if (node.nodeName === 'CODE' && node.classList.contains('var') && node.classList.contains('empty')) {
      editor.selectAllChildren(node);
    }
  }

  static onKeyDown({editor, event}) {
    const editableNode = editor.rootNode;
    if (event.key === 'Tab') {
      const nodes = editableNode.querySelectorAll('code.var');
      if (nodes.length > 0) {
        const sel = editor.currentSelection();
        let found = false;

        // First, try to find a <code> that the selection is within. If found,
        // select the next/prev node if the selection ends at the end of the
        // <code>'s text, otherwise select the <code>'s contents.
        for (let i = 0; i < nodes.length; i++) {
          const node = nodes[i];
          if (DOMUtils.selectionIsWithin(node)) {
            const selIndex = editor.getSelectionTextIndex(node);
            const length = DOMUtils.getIndexedTextContent(node).slice(-1)[0].end;
            let nextIndex = i;
            if (selIndex.endIndex === length) {
              nextIndex = event.shiftKey ? i - 1 : i + 1;
            }
            nextIndex = (nextIndex + nodes.length) % nodes.length; // allow wraparound in both directions
            sel.selectAllChildren(nodes[nextIndex]);
            found = true;
            break;
          }
        }

        // If we failed to find a <code> that the selection is within, select the
        // nearest <code> before/after the selection (depending on shift).
        if (!found) {
          const treeWalker = document.createTreeWalker(editableNode, NodeFilter.SHOW_ELEMENT + NodeFilter.SHOW_TEXT);
          let curIndex = 0;
          let nextIndex = null;
          let node = treeWalker.nextNode();
          while (node) {
            if (sel.anchorNode === node || sel.focusNode === node) break;
            if (node.nodeName === 'CODE' && node.classList.contains('var')) curIndex++;
            node = treeWalker.nextNode();
          }
          nextIndex = event.shiftKey ? curIndex - 1 : curIndex;
          nextIndex = (nextIndex + nodes.length) % nodes.length; // allow wraparound in both directions
          sel.selectAllChildren(nodes[nextIndex]);
        }

        event.preventDefault();
        event.stopPropagation();
      }
    } else if (event.key === 'Enter') {
      const nodes = editableNode.querySelectorAll('code.var');
      for (let i = 0; i < nodes.length; i++) {
        if (DOMUtils.selectionStartsOrEndsIn(nodes[i])) {
          event.preventDefault();
          event.stopPropagation();
          break;
        }
      }
    }
  }

  static onContentChanged({editor}) {
    const editableNode = editor.rootNode;
    const selection = editor.currentSelection().rawSelection;
    const isWithinNode = (node)=> {
      let test = selection.baseNode;
      while (test !== editableNode) {
        if (test === node) { return true; }
        test = test.parentNode;
      }
      return false;
    };

    const codeTags = editableNode.querySelectorAll('code.var.empty');
    return (() => {
      const result = [];
      for (let i = 0, codeTag; i < codeTags.length; i++) {
        codeTag = codeTags[i];
        codeTag.textContent = codeTag.textContent; // sets node contents to just its textContent, strips HTML
        result.push((() => {
          if (selection.containsNode(codeTag) || isWithinNode(codeTag)) {
            return codeTag.classList.remove('empty');
          }
        })());
      }
      return result;
    })();
  }
}


module.exports = TemplatesComposerExtension;
