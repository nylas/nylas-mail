import _ from 'underscore';
import classNames from 'classnames';
import ScrollRegion from './scroll-region';
import KeyCommandsRegion from './key-commands-region';
import RetinaImg from './retina-img';
import React, {Component, PropTypes} from 'react';

/**
 * Renders a list of items and renders controls to add/edit/remove items.
 * It resembles OS X's default list component.
 * An item can be a React Component, a string or number.
 *
 * EditableList handles:
 * - Keyboard and mouse interactions to select an item
 * - Input to create a new item when the add button is clicked
 * - Callback to remove item when the remove button is clicked
 * - Double click to edit item, or use an edit button icon
 *
 * @param {object} props - props for EditableList
 * @param {string} props.className - CSS class to be applied to component
 * @param {array} props.items - Items to be rendered by the list
 * @param {function} props.itemContent - A function that returns a component
 * or string for each item. To be editable, itemContent must be a string.
 * If no function is provided, each value in `items` is coerced to a string.
 * @param {(string|object)} props.selected - The selected item. This prop is
 * optional unless uou want to control the selection externally.
 * @param {boolean} props.showEditIcon - Determines wether to show edit icon
 * button on selected items
 * @param {object} props.createInputProps - Props object to be passed on to
 * the create input element. However, keep in mind that these props can not
 * override the default props that EditableList will pass to the input.
 * @param {object} props.initialState - Used for testing purposes to initialize
 * the component with a given state.
 * @param {props.onCreateItem} props.onCreateItem
 * @param {props.onDeleteItem} props.onDeleteItem
 * @param {props.onSelectItem} props.onSelectItem
 * @param {props.onReorderItem} props.onReorderItem
 * @param {props.onItemEdited} props.onItemEdited
 * @param {props.onItemCreated} props.onItemCreated
 * @class EditableList
 */
class EditableList extends Component {
  static displayName = 'EditableList';

  /**
   * If provided, this function will be called when the add button is clicked,
   * and will prevent an input to be added at the end of the list
   * @callback props.onCreateItem
   */
  /**
   * If provided, this function will be called when the delete button is clicked.
   * @callback props.onDeleteItem
   * @param {(Component|string|number)} selectedItem - The selected item.
   * @param {number} idx - The selected item idx
   */
  /**
   * If provided, this function will be called when an item has been edited. This only
   * applies to items that are not React Components.
   * @callback props.onItemEdited
   * @param {string} newValue - The new value for the item
   * @param {(string|number)} originalValue - The original value for the item
   * @param {number} idx - The index of the edited item
   */
  /**
   * If provided, this function will be called when an item is selected via click or arrow
   * keys. If the selection is cleared, it will receive null.
   * @callback props.onSelectItem
   * @param {(Component|string|number)} selectedItem - The selected item or null
   * when selection cleared
   * @param {number} idx - The index of the selected item or null when selection
   * cleared
   */
  /**
   * If provided, this function will be called when the user has entered a value to create
   * a new item in the new item input. This function will be called when the
   * user presses Enter or when the input is blurred.
   * @callback props.onItemCreated
   * @param {string} value - The value for the new item
   */
   /**
    * If provided, the user will be able to drag and drop items to re-arrange them
    * within the list. Note that dragging between lists is not supported.
    * @callback props.onReorderItem
    * @param {Object} item - The item that was dragged
    * @param {number} startIdx - The index the item was dragged from
    * @param {number} endIdx - The new index of the item, assuming it was
      already removed from startIdx.
    */
  static propTypes = {
    items: PropTypes.array.isRequired,
    itemContent: PropTypes.func,
    className: PropTypes.string,
    showEditIcon: PropTypes.bool,
    createInputProps: PropTypes.object,
    onCreateItem: PropTypes.func,
    onDeleteItem: PropTypes.func,
    onReorderItem: PropTypes.func,
    onItemEdited: PropTypes.func,
    onItemCreated: PropTypes.func,
    initialState: PropTypes.object,

    /* Optional, if you choose to control selection externally */
    selected: PropTypes.oneOfType([PropTypes.string, PropTypes.object]),
    onSelectItem: PropTypes.func,
  };

  static defaultProps = {
    items: [],
    itemContent: (item)=> item,
    className: '',
    createInputProps: {},
    showEditIcon: false,
    onDeleteItem: ()=> {},
    onItemEdited: ()=> {},
    onItemCreated: ()=> {},
  };

  constructor(props) {
    super(props);
    this.state = props.initialState || {
      dropInsertionIndex: -1,
      editingIndex: -1,
      creatingItem: false,
    };
  }

  // Helpers

  _createItem = (value)=> {
    this._clearCreatingState(()=> {
      if (value) {
        this.props.onItemCreated(value);
      }
    });
  };

  _updateItem = (value, originalItem, idx)=> {
    this._clearEditingState(()=> {
      this.props.onItemEdited(value, originalItem, idx);
    });
  };

  _getSelectedItem = ()=> {
    if (this.props.onSelectItem) {
      return this.props.selected;
    }
    return this.state.selected;
  };

  _selectItem = (item, idx)=> {
    if (this.props.onSelectItem) {
      this.props.onSelectItem(item, idx);
    } else {
      this.setState({selected: item});
    }
  };

  _clearEditingState = (callback)=> {
    this._setStateAndFocus({editingIndex: -1}, callback);
  };

  _clearCreatingState = (callback)=> {
    this._setStateAndFocus({creatingItem: false}, callback);
  };

  _setStateAndFocus = (state, callback = ()=> {})=> {
    this.setState(state, ()=> {
      this._focusSelf();
      callback();
    });
  };

  _focusSelf = ()=> {
    React.findDOMNode(this).focus();
  };

  /**
   * @private Scrolls to the dom node of the item at the provided index
   * @param {number} idx - Index of item inside the list to scroll to
   */
  _scrollTo = (idx)=> {
    if (!idx) return;
    const list = this.refs.itemsWrapper;
    const nodes = React.findDOMNode(list).querySelectorAll('.list-item');
    list.scrollTo(nodes[idx]);
  };


  // Handlers

  _onEditInputBlur = (event, item, idx)=> {
    this._updateItem(event.target.value, item, idx);
  };

  _onEditInputFocus = (event)=> {
    const input = event.target;
    // Move cursor to the end of the input
    input.selectionStart = input.selectionEnd = input.value.length;
  };

  _onEditInputKeyDown = (event, item, idx)=> {
    event.stopPropagation();
    if (_.includes(['Enter', 'Return'], event.key)) {
      this._updateItem(event.target.value, item, idx);
    } else if (event.key === 'Escape') {
      this._clearEditingState();
    }
  };

  _onCreateInputBlur = (event)=> {
    this._createItem(event.target.value);
  };

  _onCreateInputKeyDown = (event)=> {
    event.stopPropagation();
    if (_.includes(['Enter', 'Return'], event.key)) {
      this._createItem(event.target.value);
    } else if (event.key === 'Escape') {
      this._clearCreatingState();
    }
  };

  _onItemClick = (event, item, idx)=> {
    this._selectItem(item, idx);
  };

  _onItemEdit = (event, item, idx)=> {
    this.setState({editingIndex: idx});
  };

  _listKeymapHandlers = ()=> {
    const _shift = (dir) => {
      const len = this.props.items.length;
      const index = this.props.items.indexOf(this._getSelectedItem());
      const newIndex = Math.min(len - 1, Math.max(0, index + dir));
      if (index === newIndex) {
        return;
      }
      this._scrollTo(newIndex);
      this._selectItem(this.props.items[newIndex], newIndex);
    };
    return {
      'core:previous-item': (event)=> {
        event.stopPropagation();
        _shift(-1);
      },
      'core:next-item': (event)=> {
        event.stopPropagation();
        _shift(1);
      },
    };
  };

  _onCreateItem = ()=> {
    if (this.props.onCreateItem) {
      this.props.onCreateItem();
    } else {
      this.setState({creatingItem: true});
    }
  };

  _onDeleteItem = ()=> {
    const selectedItem = this._getSelectedItem();
    const index = this.props.items.indexOf(selectedItem);

    if (selectedItem) {
      // Move the selection 1 up after deleting
      const len = this.props.items.length;
      const newIndex = Math.min(len - 2, Math.max(0, index + 1));
      this.props.onDeleteItem(selectedItem, index);

      if (this.props.items[newIndex]) {
        this._selectItem(this.props.items[newIndex], newIndex);
      }
    }
  };

  _onItemDragStart = (event)=> {
    if (!this.props.onReorderItem) {
      event.preventDefault();
      return;
    }

    const row = event.target.closest('[data-item-idx]') || event.target;
    const wrapperId = React.findDOMNode(this.refs.itemsWrapper).dataset.reactid;

    if (!row.dataset.itemIdx) {
      return;
    }

    if (row.dataset.itemIdx / 1 === this.state.editingIndex / 1) {
      // dragging the row currently being edited makes text selection impossible
      event.preventDefault();
      return;
    }

    event.dataTransfer.setData('editablelist-index', row.dataset.itemIdx);
    event.dataTransfer.setData('editablelist-reactid', wrapperId);
    event.dataTransfer.effectAllowed = "move";
  };

  _onDragOver = (event)=> {
    const wrapperNode = React.findDOMNode(this.refs.itemsWrapper);
    const originWrapperId = event.dataTransfer.getData('editablelist-reactid')
    const originSameList = (originWrapperId === wrapperNode.dataset.reactid);
    let dropInsertionIndex = 0;

    if ((event.currentTarget === wrapperNode) && originSameList) {
      const itemNodes = wrapperNode.querySelectorAll('[data-item-idx]')
      for (let i = 0; i < itemNodes.length; i ++) {
        const itemNode = itemNodes[i];
        const rect = itemNode.getBoundingClientRect();
        if (event.clientY > rect.top + (rect.height / 2)) {
          dropInsertionIndex = itemNode.dataset.itemIdx / 1 + 1;
        } else {
          break;
        }
      }
    } else {
      dropInsertionIndex = -1;
    }

    if (this.state.dropInsertionIndex !== dropInsertionIndex) {
      this.setState({dropInsertionIndex: dropInsertionIndex});
    }
  };

  _onDragLeave = ()=> {
    this.setState({dropInsertionIndex: -1});
  };

  _onDrop = (event)=> {
    if (this.state.dropInsertionIndex !== -1) {
      const startIdx = event.dataTransfer.getData('editablelist-index');
      if (startIdx && (this.state.dropInsertionIndex !== startIdx)) {
        const item = this.props.items[startIdx];

        let endIdx = this.state.dropInsertionIndex;
        if (endIdx > startIdx) {
          endIdx -= 1
        }

        this.props.onReorderItem(item, startIdx, endIdx);
        this.setState({dropInsertionIndex: -1});
      }
    }
  };

  // Renderers

  _renderEditInput = (item, itemContent, idx, handlers = {})=> {
    const onInputBlur = handlers.onInputBlur || this._onEditInputBlur;
    const onInputFocus = handlers.onInputFocus || this._onEditInputFocus;
    const onInputKeyDown = handlers.onInputKeyDown || this._onEditInputKeyDown;

    return (
      <input
        autoFocus
        type="text"
        placeholder={itemContent}
        defaultValue={itemContent}
        onBlur={_.partial(onInputBlur, _, item, idx)}
        onFocus={onInputFocus}
        onKeyDown={_.partial(onInputKeyDown, _, item, idx)} />
    );
  };

  /**
   * @private Will render the create input with the provided input props.
   * Provided props will be overriden with the props that EditableList needs to
   * pass to the input.
   */
  _renderCreateInput = ()=> {
    const props = _.extend(this.props.createInputProps, {
      autoFocus: true,
      type: 'text',
      onBlur: this._onCreateInputBlur,
      onKeyDown: this._onCreateInputKeyDown,
    });

    return (
      <div className="create-item-input" key="create-item-input">
        <input {...props}/>
      </div>
    );
  };

  // handlers object for testing
  _renderItem = (item, idx, {editingIndex} = this.state, handlers = {})=> {
    const onClick = handlers.onClick || this._onItemClick;
    const onEdit = handlers.onEdit || this._onItemEdit;

    let itemContent = this.props.itemContent(item);
    const itemIsEditable = !React.isValidElement(itemContent);

    const classes = classNames({
      'list-item': true,
      'selected': item === this._getSelectedItem(),
      'editing': idx === editingIndex,
      'editable-item': itemIsEditable,
      'with-edit-icon': this.props.showEditIcon && editingIndex !== idx,
    });

    if ((editingIndex === idx) && itemIsEditable) {
      itemContent = this._renderEditInput(item, itemContent, idx, handlers);
    }

    return (
      <div
        className={classes}
        key={idx}
        data-item-idx={idx}
        draggable
        onDragStart={this._onItemDragStart}
        onClick={_.partial(onClick, _, item, idx)}
        onDoubleClick={_.partial(onEdit, _, item, idx)}>
        {itemContent}
        <RetinaImg
          className="edit-icon"
          name="edit-icon.png"
          title="Edit Item"
          mode={RetinaImg.Mode.ContentIsMask}
          onClick={_.partial(onEdit, _, item, idx)} />
      </div>
    );
  };

  _renderButtons = ()=> {
    const deleteClasses = classNames({
      'btn-editable-list': true,
      'btn-disabled': !this._getSelectedItem(),
    });
    return (
      <div className="buttons-wrapper">
        <div className="btn-editable-list" onClick={this._onCreateItem}>
          <span>+</span>
        </div>
        <div className={deleteClasses} onClick={this._onDeleteItem}>
          <span>—</span>
        </div>
      </div>
    );
  };

  _renderDropInsertion = ()=> {
    return (
      <div className="insertion-point"><div></div></div>
    )
  };

  render() {
    let items = this.props.items.map( (item, idx)=> this._renderItem(item, idx));
    if (this.state.creatingItem === true) {
      items = items.concat(this._renderCreateInput());
    }

    if (this.state.dropInsertionIndex !== -1) {
      items.splice(this.state.dropInsertionIndex, 0, this._renderDropInsertion());
    }

    return (
      <KeyCommandsRegion
        tabIndex="1"
        localHandlers={this._listKeymapHandlers()}
        className={`nylas-editable-list ${this.props.className}`}>
        <ScrollRegion
          className="items-wrapper"
          ref="itemsWrapper"
          onDragOver={this._onDragOver}
          onDragLeave={this._onDragLeave}
          onDrop={this._onDrop}>
          {items}
        </ScrollRegion>
        {this._renderButtons()}
      </KeyCommandsRegion>
    );
  }

}

export default EditableList;
