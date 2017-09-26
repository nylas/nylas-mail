import { React, PropTypes, Utils } from 'mailspring-exports';

class FluxContainer extends React.Component {
  static displayName = 'FluxContainer';
  static propTypes = {
    children: PropTypes.element,
    stores: PropTypes.array.isRequired,
    getStateFromStores: PropTypes.func.isRequired,
  };

  constructor(props) {
    super(props);
    this._unlisteners = [];
    this.state = this.props.getStateFromStores();
  }

  componentDidMount() {
    return this.setupListeners();
  }

  componentWillReceiveProps(nextProps) {
    this.setState(nextProps.getStateFromStores());
    return this.setupListeners(nextProps);
  }

  componentWillUnmount() {
    for (const unlisten of this._unlisteners) {
      unlisten();
    }
    this._unlisteners = [];
  }

  setupListeners(props = this.props) {
    for (const unlisten of this._unlisteners) {
      unlisten();
    }

    this._unlisteners = props.stores.map(store => {
      return store.listen(() => this.setState(props.getStateFromStores()));
    });
  }

  render() {
    const otherProps = Utils.fastOmit(this.props, Object.keys(this.constructor.propTypes));
    return React.cloneElement(this.props.children, Object.assign({}, otherProps, this.state));
  }
}

export default FluxContainer;
