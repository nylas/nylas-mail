import DOMWalkers from '../dom-walkers';
import Utils from '../flux/models/utils';

function textAndNodesAfterNode(node) {
  let text = '';
  let curNode = node;
  const nodes = [];
  while (curNode) {
    let sibling = curNode.nextSibling;
    while (sibling) {
      text += sibling.textContent;
      nodes.push(sibling);
      sibling = sibling.nextSibling;
    }
    curNode = curNode.parentNode;
  }
  return { text, nodes };
}

/**
 * Sometimes the last signature of an email will not be placed in a quote
 * block. This will cause out quote detector to not strip anything since
 * it looks very similar to someone writing inline regular text after some
 * quoted text (which is allowed).
 *
 * See email_18, email_20, email_21, and email_23 test cases for this.
 */
export default function unwrappedSignatureDetector(doc, quoteElements) {
  // Find the last quoteBlock
  for (const node of DOMWalkers.walkBackwards(doc)) {
    let textAndNodes;
    let focusNode = node;
    if (node && quoteElements.includes(node)) {
      textAndNodes = textAndNodesAfterNode(node);
    } else if (node.previousSibling && quoteElements.includes(node.previousSibling)) {
      focusNode = node.previousSibling;
      textAndNodes = textAndNodesAfterNode(node.previousSibling);
    } else {
      continue;
    }

    const { text, nodes } = textAndNodes;
    const maybeSig = text.replace(/\s/g, '');
    if (maybeSig.length > 0) {
      if (
        (focusNode.textContent || '').replace(/\s/g, '').search(Utils.escapeRegExp(maybeSig)) >= 0
      ) {
        return nodes;
      }
    }
    break;
  }
  return [];
}
