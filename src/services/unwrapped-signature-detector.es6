import DOMWalkers from '../dom-walkers'
import Utils from '../flux/models/utils'

function textAndNodesAfterNode(node) {
  let text = "";
  let curNode = node;
  const nodes = []
  while (curNode) {
    let sibling = curNode.nextSibling;
    while (sibling) {
      text += sibling.textContent;
      nodes.push(sibling);
      sibling = sibling.nextSibling;
    }
    curNode = curNode.parentNode;
  }
  return {text, nodes}
}

/**
 * Sometimes the last signature of an email will not be placed in a quote
 * block. This will cause out quote detector to not strip anything since
 * it looks very similar to someone writing inline regular text after some
 * quoted text (which is allowed).
 *
 * See email_20 and email_21 as a test case for this.
 */
export default function unwrappedSignatureDetector(doc, quoteElements) {
  // Find the last quoteBlock
  for (const node of DOMWalkers.walkBackwards(doc)) {
    if (quoteElements.includes(node)) {
      const {text, nodes} = textAndNodesAfterNode(node);
      const maybeSig = text.trim();
      if (maybeSig.length > 0) {
        if ((node.textContent || "").search(Utils.escapeRegExp(maybeSig)) >= 0) {
          return nodes;
        }
      }
      break;
    }
  }
  return []
}
