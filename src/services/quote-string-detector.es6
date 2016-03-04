import DOMWalkers from '../dom-walkers'

/*
 * There are semi-common cases where immediately before a blockquote, we
 * encounter a string like: "On Thu … so and so … wrote:". This should be part
 * of the blockquote but was usually left as a collection of nodes. To help
 * with false-positives, we only look for strings like that that immediately
 * preceeded the blockquoted section. By the time the function gets here, the
 * last blockquote has been removed and the text we want will be at the end of
 * the document.
 *
 * This is in its own file to make use of ES6 generators
 */
export default function quoteStringDetector(doc) {
  const quoteNodesToRemove = [];
  let seenInitialQuoteEnd = false;
  for (const node of DOMWalkers.walkBackwards(doc)) {
    if (node.nodeType === Node.TEXT_NODE && node.nodeValue.trim().length > 0) {
      if (!seenInitialQuoteEnd) {
        if (/wrote:$/gim.test(node.nodeValue)) {
          seenInitialQuoteEnd = true;
          quoteNodesToRemove.push(node);
          if (/On \S/gim.test(node.nodeValue)) {
            // The beginning of the quoted string may be in the same node
            return quoteNodesToRemove;
          }
        } else {
          // This means there's some text in between the end of the content
          // (adjacent to the blockquote) and the quote string. We shouldn't be
          // killing any text in this case.
          return quoteNodesToRemove;
        }
      } else {
        quoteNodesToRemove.push(node)
        if (/On \S/gim.test(node.nodeValue)) {
          // This means we've reached the beginning of the quoted string.
          return quoteNodesToRemove;
        }
      }
    } else {
      if (seenInitialQuoteEnd) {
        quoteNodesToRemove.push(node)
      }
    }
  }
  return quoteNodesToRemove;
}
