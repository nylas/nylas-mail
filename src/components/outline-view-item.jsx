import _ from 'underscore';
import classnames from 'classnames';
import React, {Component, PropTypes} from 'react';
import DisclosureTriangle from './disclosure-triangle';
import DropZone from './drop-zone';
import RetinaImg from './retina-img';

/**
 * Enum for counter styles
 * @readonly
 * @enum {string}
 */
const CounterStyles = {
  Default: 'def',
  Alt: 'alt',
};


/**
 * Renders an item that may contain more arbitrarily nested items
 * This component resembles OS X's default OutlineView or Sourcelist
 *
 * An OutlineViewItem behaves like a controlled React component; it controls no
 * state internally. All of the desired state must be passed in through props.
 *
 *
 * OutlineView handles:
 * - Collapsing and uncollapsing
 * - Editing value for item
 * - Deleting item
 * - Selecting the item
 * - Displaying an associated count
 * - Dropping elements
 *
 * @param {object} props - props for OutlineViewItem
 * @param {object} props.item - props for OutlineViewItem
 * @param {string} props.item.id - Unique id for the item.
 * @param {string} props.item.name - Name to display
 * @param {string} props.item.className - Extra classes to add to the item
 * @param {string} props.item.iconName - Icon name for icon. See {@link RetinaImg} for further reference.
 * @param {array} props.item.children - Array of children of the same type to be
 * displayed.
 * @param {number} props.item.count - Count to display. If falsy, wont display a
 * count.
 * @param {CounterStyles} props.item.counterStyle - One of the possible
 * CounterStyles
 * @param {string} props.item.inputPlaceholder - Placehodler to use when editing
 * item
 * @param {boolean} props.item.collapsed - Whether the OutlineViewItem is collapsed or
 * not
 * @param {boolean} props.item.editing - Whether the OutlineViewItem is being
 * edited
 * @param {boolean} props.item.selected - Whether the OutlineViewItem is selected
 * @param {props.item.shouldAcceptDrop} props.item.shouldAcceptDrop
 * @param {props.item.onCollapseToggled} props.item.onCollapseToggled
 * @param {props.item.onInputCleared} props.item.onInputCleared
 * @param {props.item.onDrop} props.item.onDrop
 * @param {props.item.onSelect} props.item.onSelect
 * @param {props.item.onDelete} props.item.onDelete
 * @param {props.item.onEdited} props.item.onEdited
 * @class OutlineViewItem
 */
class OutlineViewItem extends Component {
  static displayName = 'OutlineView'

  /**
   * If provided, this function will be called when receiving a drop. It must
   * return true if it should accept it or false otherwise.
   * @callback props.item.shouldAcceptDrop
   * @param {object} item - The current item
   * @param {object} event - The drag event
   * @return {boolean}
   */
  /**
   * If provided, this function will be called when the action to collapse or
   * uncollapse the OutlineViewItem is executed.
   * @callback props.item.onCollapseToggled
   * @param {object} item - The current item
   */
  /**
   * If provided, this function will be called when the editing input is cleared
   * via Esc key, blurring, or submiting the edit.
   * @callback props.item.onInputCleared
   * @param {object} item - The current item
   * @param {object} event - The associated event
   */
  /**
   * If provided, this function will be called when an element is dropped in the
   * item
   * @callback props.item.onDrop
   * @param {object} item - The current item
   * @param {object} event - The associated event
   */
  /**
   * If provided, this function will be called when the item is selected
   * @callback props.item.onSelect
   * @param {object} item - The current item
   */
  /**
   * If provided, this function will be called when the the delete action is
   * executed
   * @callback props.item.onDelete
   * @param {object} item - The current item
   */
  /**
   * If provided, this function will be called when the item is edited
   * @callback props.item.onEdited
   * @param {object} item - The current item
   * @param {string} value - The new value
   */
  static propTypes = {
    item: PropTypes.shape({
      className: PropTypes.string,
      id: PropTypes.string.isRequired,
      children: PropTypes.array.isRequired,
      name: PropTypes.string.isRequired,
      iconName: PropTypes.string.isRequired,
      count: PropTypes.number,
      counterStyle: PropTypes.string,
      inputPlaceholder: PropTypes.string,
      collapsed: PropTypes.bool,
      editing: PropTypes.bool,
      selected: PropTypes.bool,
      shouldAcceptDrop: PropTypes.func,
      onCollapseToggled: PropTypes.func,
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

  _onCollapseToggled = ()=> {
    this._runCallback('onCollapseToggled');
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
            onCollapseToggled={this._onCollapseToggled} />
          {this._renderItem()}
        </span>
        {this._renderChildren()}
      </div>
    );
  }
}

export default OutlineViewItem;
