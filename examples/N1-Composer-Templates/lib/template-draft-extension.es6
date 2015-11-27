import {DraftStoreExtension} from 'nylas-exports';

class TemplatesDraftStoreExtension extends DraftStoreExtension {

  static warningsForSending(draft) {
    const warnings = [];
    if (draft.body.search(/<code[^>]*empty[^>]*>/i) > 0) {
      warnings.push('with an empty template area');
    }
    return warnings;
  }

  static finalizeSessionBeforeSending(session) {
    const body = session.draft().body;
    const clean = body.replace(/<\/?code[^>]*>/g, '');
    if (body !== clean) {
      return session.changes.add({body: clean});
    }
  }

  static onMouseUp(editableNode, range) {
    const ref = range.startContainer;
    let parent = (ref != null) ? ref.parentNode : undefined;
    let parentCodeNode = null;

    while (parent && parent !== editableNode) {
      const ref1 = parent.classList;
      if (((ref1 != null) ? ref1.contains('var') : undefined) && parent.tagName === 'CODE') {
        parentCodeNode = parent;
        break;
      }
      parent = parent.parentNode;
    }

    const isSinglePoint = range.startContainer === range.endContainer && range.startOffset === range.endOffset;

    if (isSinglePoint && parentCodeNode) {
      range.selectNode(parentCodeNode);
      const selection = document.getSelection();
      selection.removeAllRanges();
      return selection.addRange(range);
    }
  }

  static onTabDown(editableNode, range, event) {
    if (event.shiftKey) {
      return this.onTabSelectNextVar(editableNode, range, event, -1);
    }
    return this.onTabSelectNextVar(editableNode, range, event, 1);
  }

  static onTabSelectNextVar(editableNode, range, event, delta) {
    if (!range) { return; }

    // Try to find the node that the selection range is
    // currently intersecting with (inside, or around)
    let parentCodeNode = null;
    const nodes = editableNode.querySelectorAll('code.var');
    for (let i = 0, node; i < nodes.length; i++) {
      node = nodes[i];
      if (range.intersectsNode(node)) {
        parentCodeNode = node;
      }
    }

    let selectNode = null;
    if (parentCodeNode) {
      if (range.startOffset === range.endOffset && parentCodeNode.classList.contains('empty')) {
        // If the current node is empty and it's a single insertion point,
        // select the current node rather than advancing to the next node
        selectNode = parentCodeNode;
      } else {
        // advance to the next code node
        const matches = editableNode.querySelectorAll('code.var');
        let matchIndex = -1;
        for (let idx = 0, match; idx < matches.length; idx++) {
          match = matches[idx];
          if (match === parentCodeNode) {
            matchIndex = idx;
            break;
          }
        }
        if (matchIndex !== -1 && matchIndex + delta >= 0 && matchIndex + delta < matches.length) {
          selectNode = matches[matchIndex + delta];
        }
      }
    }

    if (selectNode) {
      range.selectNode(selectNode);
      const selection = document.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      event.preventDefault();
      event.stopPropagation();
    }
  }

  static onInput(editableNode) {
    const selection = document.getSelection();

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


module.exports = TemplatesDraftStoreExtension;
