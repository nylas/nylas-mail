import _ from 'underscore'
import {DOMUtils, ComposerExtension, Spellchecker} from 'nylas-exports';

const recycled = [];
const MAX_MISPELLINGS = 10

function getSpellingNodeForText(text) {
  let node = recycled.pop();
  if (!node) {
    node = document.createElement('spelling');
    node.classList.add('misspelled');
  }
  node.textContent = text;
  return node;
}

function recycleSpellingNode(node) {
  recycled.push(node);
}

function whileApplyingSelectionChanges(rootNode, cb) {
  const selection = document.getSelection();
  const selectionSnapshot = {
    anchorNode: selection.anchorNode,
    anchorOffset: selection.anchorOffset,
    focusNode: selection.focusNode,
    focusOffset: selection.focusOffset,
    modified: false,
  };

  rootNode.style.display = 'none'
  cb(selectionSnapshot);
  rootNode.style.display = 'block'

  if (selectionSnapshot.modified) {
    selection.setBaseAndExtent(selectionSnapshot.anchorNode, selectionSnapshot.anchorOffset, selectionSnapshot.focusNode, selectionSnapshot.focusOffset);
  }
}

// Removes all of the <spelling> nodes found in the provided `editor`.
// It normalizes the DOM after removing spelling nodes to ensure that words
// are not split between text nodes. (ie: doesn, 't => doesn't)
function unwrapWords(rootNode) {
  whileApplyingSelectionChanges(rootNode, (selectionSnapshot) => {
    const spellingNodes = rootNode.querySelectorAll('spelling');
    for (let ii = 0; ii < spellingNodes.length; ii++) {
      const node = spellingNodes[ii];
      if (selectionSnapshot.anchorNode === node) {
        selectionSnapshot.anchorNode = node.firstChild;
      }
      if (selectionSnapshot.focusNode === node) {
        selectionSnapshot.focusNode = node.firstChild;
      }
      selectionSnapshot.modified = true;
      while (node.firstChild) {
        node.parentNode.insertBefore(node.firstChild, node);
      }
      recycleSpellingNode(node);
      node.parentNode.removeChild(node);
    }
  });
  rootNode.normalize();
}

// Traverses all of the text nodes within the provided `editor`. If it finds a
// text node with a misspelled word, it splits it, wraps the misspelled word
// with a <spelling> node and updates the selection to account for the change.
function wrapMisspelledWords(rootNode) {
  whileApplyingSelectionChanges(rootNode, (selectionSnapshot) => {
    const treeWalker = document.createTreeWalker(rootNode, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT, {
      acceptNode: (node) => {
        // skip the entire subtree inside <code> tags and <a> tags...
        if ((node.nodeType === Node.ELEMENT_NODE) && (["CODE", "A", "PRE"].includes(node.tagName))) {
          return NodeFilter.FILTER_REJECT;
        }
        return (node.nodeType === Node.TEXT_NODE) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP;
      },
    });

    const nodeList = [];

    while (treeWalker.nextNode()) {
      nodeList.push(treeWalker.currentNode);
    }

    // Note: As a performance optimization, we stop spellchecking after encountering
    // 10 misspelled words. This keeps the runtime of this method bounded!
    let nodeMisspellingsFound = 0;

    while (true) {
      const node = nodeList.shift();
      if ((node === undefined) || (nodeMisspellingsFound > MAX_MISPELLINGS)) {
        break;
      }

      const nodeContent = node.textContent;
      const nodeWordRegexp = /(\w[\w'’-]*\w|\w)/g; // https://regex101.com/r/bG5yC4/1

      while (true) {
        const match = nodeWordRegexp.exec(nodeContent);
        if ((match === null) || (nodeMisspellingsFound > MAX_MISPELLINGS)) {
          break;
        }

        if (Spellchecker.isMisspelled(match[0])) {
          // The insertion point is currently at the end of this misspelled word.
          // Do not mark it until the user types a space or leaves.
          if ((selectionSnapshot.focusNode === node) && (selectionSnapshot.focusOffset === match.index + match[0].length)) {
            continue;
          }

          const matchNode = (match.index === 0) ? node : node.splitText(match.index);
          const afterMatchNode = matchNode.splitText(match[0].length);

          const spellingSpan = getSpellingNodeForText(match[0]);
          matchNode.parentNode.replaceChild(spellingSpan, matchNode);

          for (const prop of ['anchor', 'focus']) {
            if (selectionSnapshot[`${prop}Node`] === node) {
              if (selectionSnapshot[`${prop}Offset`] > match.index + match[0].length) {
                selectionSnapshot[`${prop}Node`] = afterMatchNode;
                selectionSnapshot[`${prop}Offset`] -= match.index + match[0].length;
                selectionSnapshot.modified = true;
              } else if (selectionSnapshot[`${prop}Offset`] >= match.index) {
                selectionSnapshot[`${prop}Node`] = spellingSpan.childNodes[0];
                selectionSnapshot[`${prop}Offset`] -= match.index;
                selectionSnapshot.modified = true;
              }
            }
          }

          nodeMisspellingsFound += 1;
          nodeList.unshift(afterMatchNode);
          break;
        }
      }
    }
  });
}

let currentlyRunningSpellChecker = false;
const runSpellChecker = _.debounce((editor) => {
  if (!editor.currentSelection().isInScope()) return;
  currentlyRunningSpellChecker = true;
  unwrapWords(editor.rootNode);
  Spellchecker.handler.provideHintText(editor.rootNode.textContent).then(() => {
    wrapMisspelledWords(editor.rootNode)

    // We defer here so that when the MutationObserver fires the
    // SpellcheckComposerExtension.onContentChanged callback we will properly
    // observe that we just ran the spellchecker and won't schedule another
    // spellcheck pass (which would cause an infinite loop of spellchecking
    // once every second)
    _.defer(() => {
      currentlyRunningSpellChecker = false;
    });
  })
}, 1000)


export default class SpellcheckComposerExtension extends ComposerExtension {

  static onContentChanged({editor}) {
    if (!currentlyRunningSpellChecker) {
      runSpellChecker(editor);
    }
  }

  static onShowContextMenu({editor, menu}) {
    const selection = editor.currentSelection();
    const range = DOMUtils.Mutating.getRangeAtAndSelectWord(selection, 0);
    const word = range.toString();

    Spellchecker.appendSpellingItemsToMenu({
      menu,
      word,
      onCorrect: (correction) => {
        DOMUtils.Mutating.applyTextInRange(range, selection, correction);
        SpellcheckComposerExtension.onContentChanged({editor});
      },
      onDidLearn: () => {
        SpellcheckComposerExtension.onContentChanged({editor});
      },
    });
  }

  static applyTransformsForSending({draftBodyRootNode}) {
    const spellingEls = draftBodyRootNode.querySelectorAll('spelling');
    for (const spellingEl of Array.from(spellingEls)) {
      // move contents out of the spelling node, remove the node
      const parent = spellingEl.parentNode;
      while (spellingEl.firstChild) {
        parent.insertBefore(spellingEl.firstChild, spellingEl);
      }
      parent.removeChild(spellingEl);
    }
  }

  static unapplyTransformsForSending() {
    // no need to put spelling nodes back!
  }

}
