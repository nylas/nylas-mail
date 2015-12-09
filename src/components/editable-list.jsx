import _ from 'underscore';
import classNames from 'classnames';
import React, {Component, PropTypes} from 'react';

class EditableList extends Component {
  static displayName = 'EditableList'

  static propTypes = {
    children: PropTypes.arrayOf(PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number,
      PropTypes.element,
    ])),
    className: PropTypes.string,
    createPlaceholder: PropTypes.string,
    onCreateItem: PropTypes.func,
    onDeleteItem: PropTypes.func,
    onItemEdited: PropTypes.func,
    onItemSelected: PropTypes.func,
    onItemCreated: PropTypes.func,
    initialState: PropTypes.object,
  }

  static defaultProps = {
    children: [],
    className: '',
    createPlaceholder: '',
    onDeleteItem: ()=> {},
    onItemEdited: ()=> {},
    onItemSelected: ()=> {},
    onItemCreated: ()=> {},
  }

  constructor(props) {
    super(props);
    this._doubleClickedItem = false;
    this.state = props.initialState || {
      editing: null,
      selected: null,
      creatingItem: false,
    };
  }

  _onInputBlur = ()=> {
    this.setState({editing: null});
  }

  _onInputFocus = ()=> {
    this._doubleClickedItem = false;
  }

  _onInputKeyDown = (event, item, idx)=> {
    if (_.includes(['Enter', 'Return'], event.key)) {
      this.setState({editing: null});
      this.props.onItemEdited(event.target.value, item, idx);
    } else if (event.key === 'Escape') {
      this.setState({editing: null});
    }
  }

  _onCreateInputKeyDown = (event)=> {
    if (_.includes(['Enter', 'Return'], event.key)) {
      this.setState({creatingItem: false});
      this.props.onItemCreated(event.target.value);
    } else if (event.key === 'Escape') {
      this.setState({creatingItem: false});
    }
  }

  _onCreateInputBlur = ()=> {
    this.setState({creatingItem: false});
  }

  _onItemClick = (event, item, idx)=> {
    this._selectItem(item, idx);
  }

  _onItemDoubleClick = (event, item, idx)=> {
    if (!React.isValidElement(item)) {
      this._doubleClickedItem = true;
      this.setState({editing: idx});
    }
  }

  _onListBlur = ()=> {
    if (!this._doubleClickedItem) {
      this.setState({selected: null});
    }
  }

  _onListKeyDown = (event)=> {
    const len = this.props.children.size;
    const handle = {
      'ArrowUp': (sel)=> sel === 0 ? sel : sel - 1,
      'ArrowDown': (sel)=> sel === len - 1 ? sel : sel + 1,
      'Escape': ()=> null,
    };
    const selected = (handle[event.key] || ((sel)=> sel))(this.state.selected);
    this._selectItem(this.props.children[selected], selected);
  }

  _onCreateItem = ()=> {
    if (this.props.onCreateItem) {
      this.props.onCreateItem();
    } else {
      this.setState({creatingItem: true});
    }
  }

  _onDeleteItem = ()=> {
    const idx = this.state.selected;
    const item = this.props.children[idx];
    if (item) {
      this.props.onDeleteItem(item, idx);
    }
  }

  _selectItem = (item, idx)=> {
    this.setState({selected: idx});
    this.props.onItemSelected(item, idx);
  }

  _renderItem = (item, idx, {editing, selected} = this.state, handlers = {})=> {
    const onClick = handlers.onClick || this._onItemClick;
    const onDoubleClick = handlers.onDoubleClick || this._onItemDoubleClick;
    const onInputBlur = handlers.onInputBlur || this._onInputBlur;
    const onInputFocus = handlers.onInputFocus || this._onInputFocus;
    const onInputKeyDown = handlers.onInputKeyDown || this._onInputKeyDown;

    const classes = classNames({
      'component-item': React.isValidElement(item),
      'editable-item': !React.isValidElement(item),
      'selected': selected === idx,
    });
    let itemToRender = item;
    if (React.isValidElement(item)) {
      itemToRender = item;
    } else if (editing === idx) {
      itemToRender = (
        <input
          autoFocus
          type="text"
          placeholder={item}
          onBlur={onInputBlur}
          onFocus={onInputFocus}
          onKeyDown={_.partial(onInputKeyDown, _, item, idx)} />
      );
    }

    return (
      <div
        className={classes}
        key={idx}
        onClick={_.partial(onClick, _, item, idx)}
        onDoubleClick={_.partial(onDoubleClick, _, item, idx)}>
        {itemToRender}
      </div>
    );
  }

  _renderCreateItem = ()=> {
    return (
      <div className="create-item-input" key="create-item-input">
        <input
          autoFocus
          type="text"
          placeholder={this.props.createPlaceholder}
          onBlur={this._onCreateInputBlur}
          onKeyDown={this._onCreateInputKeyDown} />
      </div>
    );
  }

  render() {
    let items = this.props.children.map((item, idx)=> this._renderItem(item, idx));
    if (this.state.creatingItem === true) {
      items = items.concat(this._renderCreateItem());
    }

    return (
      <div className={`nylas-editable-list ${this.props.className}`}>
        <div
          className="items-wrapper"
          tabIndex="1"
          onBlur={this._onListBlur}
          onKeyDown={this._onListKeyDown}>
          {items}
        </div>
        <div className="buttons-wrapper">
          <button className="btn btn-small btn-editable-list" onClick={this._onCreateItem}>+</button>
          <button className="btn btn-small btn-editable-list" onClick={this._onDeleteItem}>—</button>
        </div>
      </div>
    );
  }

}

export default EditableList;
