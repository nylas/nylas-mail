import { React, ReactDOM, PropTypes, Utils, ComponentRegistry } from 'nylas-exports';

import UnsafeComponent from './unsafe-component';
import InjectedComponentLabel from './injected-component-label';

/**
Public: InjectedComponent makes it easy to include dynamically registered
components inside of your React render method. Rather than explicitly render
a component, such as a `<Composer>`, you can use InjectedComponent:

```coffee
<InjectedComponent matching={role:"Composer"} exposedProps={headerMessageId:123} />
```

InjectedComponent will look up the component registered with that role in the
{ComponentRegistry} and render it, passing the exposedProps (`headerMessageId={123}`) along.

InjectedComponent monitors the ComponentRegistry for changes. If a new component
is registered that matches the descriptor you provide, InjectedComponent will refresh.

If no matching component is found, the InjectedComponent renders an empty div.

Section: Component Kit
 */
export default class InjectedComponent extends React.Component {
  static displayName = 'InjectedComponent';

  /*
  Public: React `props` supported by InjectedComponent:

   - `matching` Pass an {Object} with ComponentRegistry descriptors.
      This set of descriptors is provided to {ComponentRegistry::findComponentsForDescriptor}
      to retrieve the component that will be displayed.

   - `onComponentDidRender` (optional) Callback that will be called when the injected component
      is successfully rendered onto the DOM.

   - `className` (optional) A {String} class name for the containing element.

   - `exposedProps` (optional) An {Object} with props that will be passed to each
      item rendered into the set.

   - `fallback` (optional) A {Component} to default to in case there are no matching
     components in the ComponentRegistry

   - `requiredMethods` (options) An {Array} with a list of methods that should be
     implemented by the registered component instance. If these are not implemented,
     an error will be thrown.

  */
  static propTypes = {
    matching: PropTypes.object.isRequired,
    className: PropTypes.string,
    exposedProps: PropTypes.object,
    fallback: PropTypes.func,
    onComponentDidRender: PropTypes.func,
    style: PropTypes.object,
    requiredMethods: PropTypes.arrayOf(PropTypes.string),
    onComponentDidChange: PropTypes.func,
  };

  static defaultProps = {
    style: {},
    className: '',
    exposedProps: {},
    requiredMethods: [],
    onComponentDidRender: () => {},
    onComponentDidChange: () => {},
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
    this._verifyRequiredMethods();
    this._setRequiredMethods(this.props.requiredMethods);
  }

  componentDidMount() {
    this._componentUnlistener = ComponentRegistry.listen(() => {
      this.setState(this._getStateFromStores());
    });
    if (this.state.component && this.state.component.containerRequired === false) {
      this.props.onComponentDidRender();
      this.props.onComponentDidChange();
    }
  }

  componentWillReceiveProps(newProps) {
    if (!Utils.isEqualReact(newProps.matching, this.props && this.props.matching)) {
      this.setState(this._getStateFromStores(newProps));
    }
  }

  componentDidUpdate(prevProps, prevState) {
    this._setRequiredMethods(this.props.requiredMethods);
    if (this.state.component && this.state.component.containerRequired === false) {
      this.props.onComponentDidRender();
      if (this.state.component !== prevState.component) {
        this.props.onComponentDidChange();
      }
    }
  }

  componentWillUnmount() {
    if (this._componentUnlistener) {
      this._componentUnlistener();
    }
  }

  focus = () => {
    this._runInnerDOMMethod('focus');
  };

  blur = () => {
    this._runInnerDOMMethod('blur');
  };

  // Private: Attempts to run the DOM method, ie 'focus', on
  // 1. Any implementation provided by the inner component
  // 2. Any native implementation provided by the DOM
  // 3. Ourselves, so that the method always has /some/ effect.
  //
  _runInnerDOMMethod = (method, ...rest) => {
    let target = null;
    if (this.refs.inner instanceof UnsafeComponent && this.refs.inner.injected[method]) {
      target = this.refs.inner.injected;
    } else if (this.refs.inner && this.refs.inner[method]) {
      target = this.refs.inner;
    } else if (this.refs.inner) {
      target = ReactDOM.findDOMNode(this.refs.inner);
    } else {
      target = ReactDOM.findDOMNode(this);
    }
    if (target[method]) {
      target[method].bind(target)(...rest);
    }
  };

  _setRequiredMethods = methods => {
    methods.forEach(method => {
      Object.defineProperty(this, method, {
        configurable: true,
        enumerable: true,
        value: (...rest) => this._runInnerDOMMethod(method, ...rest),
      });
    });
  };

  _verifyRequiredMethods = () => {
    if (this.state.component) {
      const component = this.state.component;
      this.props.requiredMethods.forEach(method => {
        if (component.prototype[method] === undefined) {
          throw new Error(
            `${component.name} must implement method ${method} when registering for ${JSON.stringify(
              this.props.matching
            )}`
          );
        }
      });
    }
  };

  _getStateFromStores = (props = this.props) => {
    const components = ComponentRegistry.findComponentsMatching(props.matching);
    if (components.length > 1) {
      console.warn(
        `There are multiple components available for ${JSON.stringify(
          props.matching
        )}. <InjectedComponent> is only rendering the first one.`
      );
    }
    return {
      component: components.length === 0 ? this.props.fallback : components[0],
      visible: ComponentRegistry.showComponentRegions(),
    };
  };

  render() {
    if (!this.state.component) {
      return <div />;
    }
    const exposedProps = Object.assign({}, this.props.exposedProps, {
      fallback: this.props.fallback,
    });
    let className = this.props.className;
    if (this.state.visible) {
      className += ' registered-region-visible';
    }

    const Component = this.state.component;
    let element = null;

    if (Component.containerRequired === false) {
      const privateProps = {
        key: Component.displayName,
      };
      if (Object.prototype.isPrototypeOf.call(React.Component, Component)) {
        privateProps.ref = 'inner';
      }
      element = <Component {...privateProps} {...exposedProps} />;
    } else {
      element = (
        <UnsafeComponent
          ref="inner"
          style={this.props.style}
          className={className}
          key={Component.displayName}
          component={Component}
          onComponentDidRender={this.props.onComponentDidRender}
          {...exposedProps}
        />
      );
    }

    if (this.state.visible) {
      return (
        <div className={className} style={this.props.style}>
          {element}
          <InjectedComponentLabel matching={this.props.matching} {...exposedProps} />
          <span style={{ clear: 'both' }} />
        </div>
      );
    }
    return (
      <div className={className} style={this.props.style}>
        {element}
      </div>
    );
  }
}
