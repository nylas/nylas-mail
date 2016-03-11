import _ from 'underscore'
import React from 'react'

const VirtualDOMUtils = {
  *walk({element, parentNode, childOffset, pruneFn = ()=>{}}) {
    yield {element, parentNode, childOffset};
    if (React.isValidElement(element) && !pruneFn(element)) {
      const children = element.props.children;
      if (!children) {
        return
      } else if (_.isString(children)) {
        yield {element: children, parentNode: element, childOffset: 0}
      } else if (children.length > 0) {
        for (let i = 0; i < children.length; i++) {
          yield *this.walk({element: children[i], parentNode: element, childOffset: i, pruneFn})
        }
      } else {
        yield *this.walk({element: children, parentNode: element, childOffset: 0, pruneFn})
      }
    } else if (_.isArray(element)) {
      for (let i = 0; i < element.length; i++) {
        yield *this.walk({element: element[i], parentNode: element, childOffset: i})
      }
    }
    return
  },
}
export default VirtualDOMUtils
