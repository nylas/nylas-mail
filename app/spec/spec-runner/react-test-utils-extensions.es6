/* eslint react/no-render-return-value: 0 */
import _ from 'underscore';
import ReactDOM from 'react-dom';
import ReactTestUtils from 'react-dom/test-utils';

export function scryRenderedComponentsWithTypeAndProps(root, type, props) {
  if (!root) {
    throw new Error('Must supply a root to scryRenderedComponentsWithTypeAndProps');
  }
  return _.compact(
    _.map(ReactTestUtils.scryRenderedComponentsWithType(root, type), el => {
      if (_.isEqual(_.pick(el.props, Object.keys(props)), props)) {
        return el;
      }
      return false;
    })
  );
}

let ReactElementContainers = [];
// Override ReactTestUtils.renderIntoDocument so that
// we can remove all the created elements after the test completes.
export function renderIntoDocument(element) {
  const container = document.createElement('div');
  ReactElementContainers.push(container);
  return ReactDOM.render(element, container);
}

export function unmountAll() {
  for (let i = 0; i < ReactElementContainers.length; i++) {
    const container = ReactElementContainers[i];
    ReactDOM.unmountComponentAtNode(container);
  }
  ReactElementContainers = [];
}
