import _ from 'underscore'
import React from 'react'
import SearchMatch from './search-match'
import UnifiedDOMParser from './unified-dom-parser'
import {VirtualDOMUtils} from 'nylas-exports'

export default class VirtualDOMParser extends UnifiedDOMParser {
  getWalker(dom) {
    const pruneFn = (node) => {
      return node.type === "style";
    }
    return VirtualDOMUtils.walk({element: dom, pruneFn});
  }

  isTextNode({element}) {
    return (typeof element === "string")
  }

  textNodeLength({element}) {
    return element.length
  }

  textNodeContents(textNode) {
    return textNode.element
  }

  looksLikeBlockElement({element}) {
    if (!element) { return false; }
    const blockTypes = ["br", "p", "blockquote", "div", "table", "iframe"]
    if (_.isFunction(element.type)) {
      return true
    } else if (blockTypes.indexOf(element.type) >= 0) {
      return true
    }
    return false
  }

  getRawFullString(fullString) {
    return _.pluck(fullString, "element").join('');
  }

  removeMatchesAndNormalize(element) {
    let newChildren = [];
    let strAccumulator = [];

    const resetAccumulator = () => {
      if (strAccumulator.length > 0) {
        newChildren.push(strAccumulator.join(''));
        strAccumulator = [];
      }
    }

    if (React.isValidElement(element) || _.isArray(element)) {
      let children;

      if (_.isArray(element)) {
        children = element;
      } else {
        children = element.props.children;
      }

      if (!children) {
        newChildren = null
      } else if (React.isValidElement(children)) {
        newChildren = children
      } else if (typeof children === "string") {
        strAccumulator.push(children)
      } else if (children.length > 0) {
        for (let i = 0; i < children.length; i++) {
          const child = children[i];
          if (typeof child === "string") {
            strAccumulator.push(child)
          } else if (this._isSearchElement(child)) {
            resetAccumulator();
            newChildren.push(child.props.children);
          } else {
            resetAccumulator();
            newChildren.push(this.removeMatchesAndNormalize(child));
          }
        }
      } else {
        newChildren = children
      }

      resetAccumulator();

      if (_.isArray(element)) {
        return newChildren;
      }
      return React.cloneElement(element, {}, newChildren)
    }
    return element;
  }
  _isSearchElement(element) {
    return element.type === SearchMatch
  }

  createTextNode({rawText}) {
    return rawText
  }
  createMatchNode({matchText, regionId, isCurrentMatch, renderIndex}) {
    const className = isCurrentMatch ? "current-match" : ""
    return React.createElement(SearchMatch, {className, regionId, renderIndex}, matchText);
  }
  textNodeKey(textElement) {
    return textElement.parentNode
  }

  highlightSearch(element, matchNodeMap) {
    if (React.isValidElement(element) || _.isArray(element)) {
      let newChildren = []
      let children;

      if (_.isArray(element)) {
        children = element;
      } else {
        children = element.props.children;
      }

      const matchNode = matchNodeMap.get(element);
      let originalTextNode = null;
      let newTextNodes = [];
      if (matchNode) {
        originalTextNode = matchNode.originalTextNode;
        newTextNodes = matchNode.newTextNodes;
      }

      if (!children) {
        newChildren = null
      } else if (React.isValidElement(children)) {
        if (originalTextNode && originalTextNode.childOffset === 0) {
          newChildren = newTextNodes
        } else {
          newChildren = this.highlightSearch(children, matchNodeMap)
        }
      } else if (!_.isString(children) && children.length > 0) {
        for (let i = 0; i < children.length; i++) {
          const child = children[i];
          if (originalTextNode && originalTextNode.childOffset === i) {
            newChildren.push(newTextNodes)
          } else {
            newChildren.push(this.highlightSearch(child, matchNodeMap))
          }
        }
      } else {
        if (originalTextNode && originalTextNode.childOffset === 0) {
          newChildren = newTextNodes
        } else {
          newChildren = children
        }
      }

      if (_.isArray(element)) {
        return newChildren;
      }
      return React.cloneElement(element, {}, newChildren)
    }
    return element;
  }

}
