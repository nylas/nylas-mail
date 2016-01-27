import classnames from 'classnames';
import React, {Component, PropTypes} from 'react';
import DisclosureTriangle from './disclosure-triangle';
import DropZone from './drop-zone';
import RetinaImg from './retina-img';


const CounterStyles = {
  Default: 'def',
  Alt: 'alt',
};


// TODO Docs
class OutlineViewItem extends Component {
  static displayName = 'OutlineView'

  static propTypes = {
    item: PropTypes.shape({
      id: PropTypes.string.isRequired,
      children: PropTypes.array.isRequired,
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
    }).isRequired,
  }

  state = {
    isDropping: false,
  }

  componentDidMount() {
    if (this.props.item.onDelete) {
      React.findDOMNode(this).addEventListener('contextmenu', this._onShowContextMenu);
    }
  }

  shouldComponentUpdate() {
    // TODO
    return true;
  }

  componentWillUnmount() {
    if (this.props.item.onDelete) {
      React.findDOMNode(this).removeEventListener('contextmenu', this._onShowContextMenu);
    }
  }

  static CounterStyles = CounterStyles;


  // Helpers

  _runCallback = (method, ...args)=> {
    const item = this.props.item;
    if (item[method]) {
      return item[method](item, ...args);
    }
    return undefined;
  }


  // Handlers

  _onDragStateChange = ({isDropping})=> {
    this.setState({isDropping});
  }

  _onDrop = (event)=> {
    this._runCallback('onDrop', event);
  }

  _onToggleCollapsed = ()=> {
    this._runCallback('onToggleCollapsed');
  }

  _onClick = (event)=> {
    event.preventDefault();
    this._runCallback('onSelect');
  }

  _onDelete = ()=> {
    this._runCallback('onDelete');
  }

  _shouldAcceptDrop = (event)=> {
    return this._runCallback('shouldAcceptDrop', event);
  }

  _onShowContextMenu = ()=> {
    const item = this.props.item;
    const name = item.name;
    const {remote} = require('electron');
    const {Menu, MenuItem} = remote.require('electron');

    const menu = new Menu();
    menu.append(new MenuItem({
      label: `Delete ${name}`,
      click: this._onDelete,
    }));
    menu.popup(remote.getCurrentWindow());
  }


  // Renderers

  _renderCount(item = this.props.item) {
    if (!item.count) return <span></span>;
    const className = classnames({
      'item-count-box': true,
      'alt-count': item.counterStyle === CounterStyles.Alt,
    });
    return <div className={className}>{item.count}</div>;
  }

  _renderIcon(item = this.props.item) {
    return (
      <RetinaImg
        name={item.iconName}
        fallback={'folder.png'}
        mode={RetinaImg.Mode.ContentIsMask} />
    );
  }

  _renderItem(item = this.props.item, state = this.state) {
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
        shouldAcceptDrop={this._shouldAcceptDrop}
        onDragStateChange={this._onDragStateChange}
        onDrop={this._onDrop}>
        {this._renderCount()}
        <div className="icon">{this._renderIcon()}</div>
        <div className="name">{item.name}</div>
      </DropZone>
    );
  }

  _renderChildren(item = this.props.item) {
    if (item.children.length > 0 && !item.collapsed) {
      return (
        <section className="item-children" key={`${item.id}-children`}>
          {item.children.map(
            child => <OutlineViewItem key={child.id} item={child} />
          )}
        </section>
      );
    }
    return <span></span>;
  }

  render() {
    const item = this.props.item;

    return (
      <div>
        <span className="item-container">
          <DisclosureTriangle
            collapsed={item.collapsed}
            visible={item.children.length > 0}
            onToggleCollapsed={this._onToggleCollapsed} />
          {this._renderItem()}
        </span>
        {this._renderChildren()}
      </div>
    );
  }
}

export default OutlineViewItem;
