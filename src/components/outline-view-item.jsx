import _ from 'underscore';
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
      className: PropTypes.string,
      id: PropTypes.string.isRequired,
      children: PropTypes.array.isRequired,
      name: PropTypes.string.isRequired,
      iconName: PropTypes.string.isRequired,
      count: PropTypes.number,
      counterStyle: PropTypes.string,
      dataTransferType: PropTypes.string,
      inputPlaceholder: PropTypes.string,
      collapsed: PropTypes.bool,
      editing: PropTypes.bool,
      selected: PropTypes.bool,
      shouldAcceptDrop: PropTypes.func,
      onToggleCollapsed: PropTypes.func,
      onInputCleared: PropTypes.func,
      onDrop: PropTypes.func,
      onSelect: PropTypes.func,
      onDelete: PropTypes.func,
      onEdited: PropTypes.func,
    }).isRequired,
  }


  constructor(props) {
    super(props);
    this.state = {
      isDropping: false,
      editing: props.item.editing || false,
    }
  }

  componentDidMount() {
    if (this._shouldShowContextMenu()) {
      React.findDOMNode(this).addEventListener('contextmenu', this._onShowContextMenu);
    }
  }

  componentWillReceiveProps(newProps) {
    if (newProps.editing) {
      this.setState({editing: newProps.editing});
    }
  }

  shouldComponentUpdate() {
    // TODO
    return true;
  }

  componentWillUnmount() {
    if (this._shouldShowContextMenu()) {
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

  _shouldShowContextMenu = ()=> {
    return this.props.item.onDelete != null || this.props.item.onEdited != null;
  }

  _shouldAcceptDrop = (event)=> {
    return this._runCallback('shouldAcceptDrop', event);
  }

  _clearEditingState = (event)=> {
    this.setState({editing: false});
    this._runCallback('onInputCleared', event);
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

  _onEdited = (value)=> {
    this._runCallback('onEdited', value);
  }

  _onEdit = ()=> {
    this.setState({editing: true});
  }

  _onInputFocus = (event)=> {
    const input = event.target;
    input.selectionStart = input.selectionEnd = input.value.length;
  }

  _onInputBlur = (event)=> {
    this._clearEditingState(event);
  }

  _onInputKeyDown = (event)=> {
    if (event.key === 'Escape') {
      this._clearEditingState(event);
    }
    if (_.includes(['Enter', 'Return'], event.key)) {
      this._onEdited(event.target.value);
      this._clearEditingState(event);
    }
  }

  _onShowContextMenu = (event)=> {
    event.stopPropagation()
    const item = this.props.item;
    const name = item.name;
    const {remote} = require('electron');
    const {Menu, MenuItem} = remote.require('electron');
    const menu = new Menu();

    if (this.props.item.onEdited) {
      menu.append(new MenuItem({
        label: `Edit ${name}`,
        click: this._onEdit,
      }));
    }

    if (this.props.item.onDelete) {
      menu.append(new MenuItem({
        label: `Delete ${name}`,
        click: this._onDelete,
      }));
    }
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
      <div className="icon">
        <RetinaImg
          name={item.iconName}
          fallback={'folder.png'}
          mode={RetinaImg.Mode.ContentIsMask} />
      </div>
    );
  }

  _renderItemContent(item = this.props.item, state = this.state) {
    if (state.editing) {
      const placeholder = item.inputPlaceholder || '';
      return (
        <input
          autoFocus
          type="text"
          tabIndex="1"
          className="item-input"
          placeholder={placeholder}
          defaultValue={item.name}
          onBlur={this._onInputBlur}
          onFocus={this._onInputFocus}
          onKeyDown={this._onInputKeyDown} />
      );
    }
    return <div className="name">{item.name}</div>;
  }

  _renderItem(item = this.props.item, state = this.state) {
    const containerClass = classnames({
      'item': true,
      'selected': item.selected,
      'dropping': state.isDropping,
      'editing': state.editing,
      [item.className]: item.className,
    });

    return (
      <DropZone
        id={item.id}
        className={containerClass}
        onDrop={this._onDrop}
        onClick={this._onClick}
        onDoubleClick={this._onEdit}
        shouldAcceptDrop={this._shouldAcceptDrop}
        onDragStateChange={this._onDragStateChange} >
        {this._renderCount()}
        {this._renderIcon()}
        {this._renderItemContent()}
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
