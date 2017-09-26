import { React, PropTypes, Utils, ComponentRegistry } from 'mailspring-exports';

import UnsafeComponent from './unsafe-component';
import Flexbox from './flexbox';
import InjectedComponentLabel from './injected-component-label';

/**
Public: InjectedComponent makes it easy to include a set of dynamically registered
components inside of your React render method. Rather than explicitly render
an array of buttons, for example, you can use InjectedComponentSet:

```jsx
  <InjectedComponentSet
    className="message-actions"
    matching={{role: 'ThreadActionButton'}}
    exposedProps={{thread:this.props.thread, message:this.props.message}}
  />
```

InjectedComponentSet will look up components registered for the location you provide,
render them inside a {Flexbox} and pass them `exposedProps`. By default, all injected
children are rendered inside {UnsafeComponent} wrappers to prevent third-party code
from throwing exceptions that break React renders.

InjectedComponentSet monitors the ComponentRegistry for changes. If a new component
is registered into the location you provide, InjectedComponentSet will re-render.

If no matching components is found, the InjectedComponent renders an empty span.

Section: Component Kit
 */
export default class InjectedComponentSet extends React.Component {
  static displayName = 'InjectedComponentSet';

  /*
  Public: React `props` supported by InjectedComponentSet:

   - `matching` Pass an {Object} with ComponentRegistry descriptors
      This set of descriptors is provided to {ComponentRegistry::findComponentsForDescriptor}
      to retrieve components for display.
   - `matchLimit` (optional) A {Number} that indicates the max number of matching elements to render
   - `className` (optional) A {String} class name for the containing element.
   - `children` (optional) Any React elements rendered inside the InjectedComponentSet
      will always be displayed.
   - `onComponentsDidRender` Callback that will be called when the injected component set
      is successfully rendered onto the DOM.
   - `exposedProps` (optional) An {Object} with props that will be passed to each
      item rendered into the set.
   - `containersRequired` (optional). Pass false to optionally remove the containers
      placed around injected components to isolate them from the rest of the app.

   -  Any other props you provide, such as `direction`, `data-column`, etc.
      will be applied to the {Flexbox} rendered by the InjectedComponentSet.
  */
  static propTypes = {
    matching: PropTypes.object.isRequired,
    children: PropTypes.array,
    className: PropTypes.string,
    matchLimit: PropTypes.number,
    exposedProps: PropTypes.object,
    containersRequired: PropTypes.bool,
    onComponentsDidRender: PropTypes.func,
  };

  static defaultProps = {
    direction: 'row',
    className: '',
    exposedProps: {},
    containersRequired: true,
    onComponentsDidRender: () => {},
  };

  constructor(props, context) {
    super(props, context);
    this.state = this._getStateFromStores();
    this._renderedComponents = new Set();
  }

  componentDidMount() {
    this._componentUnlistener = ComponentRegistry.listen(() =>
      this.setState(this._getStateFromStores())
    );
    if (this.props.containersRequired === false) {
      this.props.onComponentsDidRender();
    }
  }

  componentWillReceiveProps(newProps) {
    if (!this.props || !Utils.isEqualReact(newProps.matching, this.props.matching)) {
      this.setState(this._getStateFromStores(newProps));
    }
  }

  componentDidUpdate() {
    if (this.props.containersRequired === false) {
      this.props.onComponentsDidRender();
    }
  }

  componentWillUnmount() {
    if (this._componentUnlistener) {
      this._componentUnlistener();
    }
  }

  _onComponentDidRender = componentName => {
    this._renderedComponents.add(componentName);
    if (this._renderedComponents.size === this.state.components.length) {
      this.props.onComponentsDidRender();
    }
  };

  _getStateFromStores = (props = this.props) => {
    return {
      components: ComponentRegistry.findComponentsMatching(props.matching).slice(
        0,
        props.matchLimit
      ),
      visible: ComponentRegistry.showComponentRegions(),
    };
  };

  render() {
    const { className, exposedProps, containersRequired, matching, children } = this.props;

    this._renderedComponents = new Set();
    const flexboxProps = Utils.fastOmit(this.props, Object.keys(this.constructor.propTypes));
    let flexboxClassName = className;

    const elements = this.state.components.map(Component => {
      if (containersRequired === false || Component.containerRequired === false) {
        return <Component key={Component.displayName} {...exposedProps} />;
      }
      return (
        <UnsafeComponent
          key={Component.displayName}
          component={Component}
          onComponentDidRender={() => this._onComponentDidRender(Component.displayName)}
          {...exposedProps}
        />
      );
    });

    if (this.state.visible) {
      flexboxClassName += ' registered-region-visible';
      elements.splice(
        0,
        0,
        <InjectedComponentLabel key="_label" matching={matching} {...exposedProps} />
      );
      elements.push(<span key="_clear" style={{ clear: 'both' }} />);
    }

    return (
      <Flexbox className={flexboxClassName} {...flexboxProps}>
        {elements}
        {children}
      </Flexbox>
    );
  }
}
