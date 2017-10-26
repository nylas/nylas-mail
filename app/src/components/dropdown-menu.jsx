import { React, ReactDOM, PropTypes } from 'mailspring-exports';
import { Menu } from 'mailspring-component-kit';

export default class DropdownMenu extends React.Component {
  static propTypes = {
    intitialSelectionItem: PropTypes.object,
    onSelect: PropTypes.func,
    itemContent: PropTypes.func,
    headerComponents: PropTypes.node,
  };

  constructor(props) {
    super(props);
    this.state = {
      expanded: false,
      currentSelection: this.props.intitialSelectionItem,
    };
  }

  componentWillReceiveProps(nextProps) {
    this.setState({ currentSelection: nextProps.intitialSelectionItem });
  }

  _toggleExpanded = () => {
    this.setState({ expanded: !this.state.expanded }, () => {
      if (this.state.expanded) {
        const searchInput = ReactDOM.findDOMNode(this).querySelector('input');
        if (searchInput) {
          searchInput.focus();
        }
      }
    });
  };

  _close = () => {
    if (this.state.expanded) {
      this.setState({ expanded: false });
    }
  };

  _onSelect = item => {
    this.setState({ currentSelection: item });
    if (this.props.onSelect) {
      this.props.onSelect(item);
    }
    this._close();
  };

  _onBlur = e => {
    const node = ReactDOM.findDOMNode(this);
    let otherNode = e.relatedTarget;
    if (otherNode) {
      while (otherNode.parentElement) {
        // Don't close the dropdown if the related target is a child of this component
        if (otherNode.parentElement === node) {
          return;
        }
        otherNode = otherNode.parentElement;
      }
    }
    this._close();
  };

  render() {
    let dropdown = <span />;
    if (this.state.expanded) {
      dropdown = <Menu {...this.props} onEscape={this._close} onSelect={this._onSelect} />;
    }
    return (
      <div
        className="dropdown-menu"
        tabIndex="-1"
        onBlur={this._onBlur}
        style={{ display: 'inline-block' }}
      >
        <div onClick={this._toggleExpanded} style={{ cursor: 'pointer', marginLeft: '12px' }}>
          {this.props.itemContent(this.state.currentSelection)}
        </div>
        <div style={{ position: 'absolute', zIndex: '10' }}>{dropdown}</div>
      </div>
    );
  }
}
