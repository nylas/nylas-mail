import classnames from 'classnames';
import React, {Component, PropTypes} from 'react';
import DisclosureTriangle from './disclosure-triangle';
import DropZone from './drop-zone';
import RetinaImg from './retina-img';


const CounterStyles = {
  Default: 'def',
  Alt: 'alt',
}

class OutlineViewItem extends Component {
  static displayName = 'OutlineView'

  static propTypes = {
    id: PropTypes.string.isRequired,
    children: PropTypes.array,
    name: PropTypes.string.isRequired,
    iconName: PropTypes.string.isRequired,
    count: PropTypes.number,
    counterStyle: PropTypes.string,
    dataTransferType: PropTypes.string,
    collapsed: PropTypes.bool,
    deleted: PropTypes.bool,
    selected: PropTypes.bool,
    shouldAcceptDrop: PropTypes.func,
    onToggleCollapsed: PropTypes.func,
    onDrop: PropTypes.func,
    onSelect: PropTypes.func,
    onDelete: PropTypes.func,
  }

  static defaultProps = {
    children: [],
    count: 0,
    counterStyle: CounterStyles.Default,
    dataTransferType: '',
    collapsed: false,
    deleted: false,
    selected: false,
    shouldAcceptDrop: ()=> false,
    onToggleCollapsed: ()=> {},
    onDrop: ()=> {},
    onSelect: ()=> {},
  }

  state = {
    isDropping: false,
  }

  componentDidMount() {
    if (this.props.onDelete != null) {
      React.findDOMNode(this).addEventListener('contextmenu', this._onShowContextMenu);
    }
  }

  shouldComponentUpdate() {
    // TODO
    return true;
  }

  componentWillUnmount() {
    if (this.props.onDelete != null) {
      React.findDOMNode(this).removeEventListener('contextmenu', this._onShowContextMenu);
    }
  }

  static CounterStyles = CounterStyles;


  // Handlers

  _onShowContextMenu = ()=> {
    const item = this.props;
    const name = item.name;
    const {remote} = require('electron');
    const {Menu, MenuItem} = remote.require('electron');

    const menu = new Menu();
    menu.append(new MenuItem({
      name: `Delete ${name}`,
      click: ()=> {
        item.onDelete(item.id);
      },
    }));
    menu.popup(remote.getCurrentWindow());
  }

  _onDragStateChange = ({isDropping})=> {
    this.setState({isDropping});
  }

  _onDrop = (event)=> {
    const jsonString = event.dataTransfer.getData(this.props.dataTransferType);
    let ids;
    try {
      ids = JSON.parse(jsonString);
    } catch (err) {
      console.error('OutlineViewItem onDrop: JSON parse #{err}');
    }
    if (!ids) return;

    this.props.onDrop(ids);
  }

  _onClick = (event)=> {
    event.preventDefault();
    this.props.onSelect(this.props.id);
  }


  // Renderers

  _renderCount(item = this.props) {
    if (!item.count) return <span></span>;
    const className = classnames({
      'item-count-box': true,
      'alt-count': item.counterStyle === CounterStyles.Alt,
    });
    return <div className={className}>{item.count}</div>;
  }

  _renderIcon(item = this.props) {
    return (
      <RetinaImg
        name={item.iconName}
        fallback={'folder.png'}
        mode={RetinaImg.Mode.ContentIsMask} />
    );
  }

  _renderItem(item = this.props, state = this.state) {
    const containerClass = classnames({
      'item': true,
      'selected': item.selected,
      'dropping': state.isDropping,
      'deleted': item.deleted,
    });

    return (
      <DropZone
        className={containerClass}
        onClick={this._onClick}
        id={item.id}
        shouldAcceptDrop={item.shouldAcceptDrop}
        onDragStateChange={this._onDragStateChange}
        onDrop={this._onDrop}>
        {this._renderCount()}
        <div className="icon">{this._renderIcon()}</div>
        <div className="name">{item.name}</div>
      </DropZone>
    );
  }

  _renderChildren(item = this.props) {
    if (item.children.length > 0 && !item.collapsed) {
      return (
        <section key={`${item.id}-children`}>
          {item.children.map(
            child => <OutlineViewItem key={child.id} {...child} />
          )}
        </section>
      );
    }
    return <span></span>;
  }

  render() {
    const item = this.props;
    return (
      <div>
        <span className="item-container">
          <DisclosureTriangle
            collapsed={item.collapsed}
            visible={item.children.length > 0}
            onToggleCollapsed={item.onToggleCollapsed} />
          {this._renderItem()}
        </span>
        {this._renderChildren()}
      </div>
    );
  }
}

export default OutlineViewItem;
