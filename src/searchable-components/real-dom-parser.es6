import _ from 'underscore'
import UnifiedDOMParser from './unified-dom-parser'
import {DOMUtils} from 'nylas-exports'

export default class RealDOMParser extends UnifiedDOMParser {
  *_pruningDOMWalker({node, pruneFn, filterFn}) {
    if (filterFn(node)) {
      yield node;
    }
    if (node && !pruneFn(node) && node.childNodes.length > 0) {
      for (let i = 0; i < node.childNodes.length; i++) {
        yield *this._pruningDOMWalker({node: node.childNodes[i], pruneFn, filterFn});
      }
    }
    return;
  }

  getWalker(dom) {
    const filterFn = (node) => {
      return node.nodeType === Node.TEXT_NODE
    }
    const pruneFn = (node) => {
      return node.nodeName === "STYLE"
    }
    return this._pruningDOMWalker({node: dom, pruneFn, filterFn});
  }

  isTextNode(node) {
    return node.nodeType === Node.TEXT_NODE
  }

  textNodeLength(textNode) {
    return (textNode.data || "").length
  }

  textNodeContents(textNode) {
    return (textNode.data)
  }

  looksLikeBlockElement(node) {
    return DOMUtils.looksLikeBlockElement(node)
  }

  getRawFullString(fullString) {
    return _.pluck(fullString, "data").join('');
  }

  removeMatchesAndNormalize(element) {
    const matches = element.querySelectorAll('search-match');
    if (matches.length === 0) { return null }
    for (let i = 0; i < matches.length; i++) {
      const match = matches[i];
      DOMUtils.unwrapNode(match)
    }
    element.normalize();
    return element
  }

  createTextNode({rawText}) {
    return document.createTextNode(rawText);
  }
  createMatchNode({matchText, regionId, isCurrentMatch, renderIndex}) {
    const text = document.createTextNode(matchText);
    const newNode = document.createElement('search-match');
    const className = isCurrentMatch ? "current-match" : "";
    newNode.setAttribute('data-region-id', regionId)
    newNode.setAttribute('data-render-index', renderIndex)
    newNode.setAttribute('class', className)
    newNode.appendChild(text);
    return newNode
  }
  textNodeKey(textElement) {
    return textElement;
  }

  highlightSearch(element, matchNodeMap) {
    const walker = this.getWalker(element);
    // We have to expand the whole generator because we're mutating in
    // place
    const textNodes = [...walker]
    for (const textNode of textNodes) {
      if (matchNodeMap.has(textNode)) {
        const {originalTextNode, newTextNodes} = matchNodeMap.get(textNode);
        const frag = document.createDocumentFragment();
        for (const newNode of newTextNodes) {
          frag.appendChild(newNode);
        }
        textNode.parentNode.replaceChild(frag, originalTextNode)
      }
    }
  }
}
